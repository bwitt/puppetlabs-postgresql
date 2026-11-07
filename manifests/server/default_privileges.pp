# @summary Manage a database defaults privileges. Only works with PostgreSQL version 9.6 and above.
#
# @param target_role Target role whose created objects will receive the default privileges. Defaults to the current user.
# @param ensure Specifies whether to grant or revoke the privilege.
# @param role Specifies the role or user whom you are granting access to.
# @param db Specifies the database to which you are granting access.
# @param object_type Specify target object type: 'FUNCTIONS', 'ROUTINES', 'SEQUENCES', 'TABLES', 'TYPES'.
# @param privilege Specifies comma-separated list of privileges to grant. Valid options: depends on object type.
# @param schema Target schema. Defaults to 'public'. Can be set to '' to apply to all schemas.
# @param psql_db Defines the database to execute the grant against. This should not ordinarily be changed from the default.
# @param psql_user Specifies the OS user for running psql. Default value: The default user for the module, usually 'postgres'.
# @param psql_path Specifies the OS user for running psql. Default value: The default user for the module, usually 'postgres'.
# @param port Specifies the port to access the server. Default value: The default user for the module, usually '5432'.
# @param connect_settings Specifies a hash of environment variables used when connecting to a remote server.
# @param instance The name of the Postgresql database instance.
# @param group Specifies the user group to which the privileges will be granted.
define postgresql::server::default_privileges (
  String $role,
  String $db,
  String $privilege,
  Pattern[
    /(?i:^FUNCTIONS$)/,
    /(?i:^ROUTINES$)/,
    /(?i:^SEQUENCES$)/,
    /(?i:^TABLES$)/,
    /(?i:^TYPES$)/,
    /(?i:^SCHEMAS$)/
  ] $object_type,
  String                    $schema            = 'public',
  String                    $psql_db           = $postgresql::server::default_database,
  String                    $psql_user         = $postgresql::server::user,
  Stdlib::Port              $port              = $postgresql::server::port,
  Hash                      $connect_settings  = $postgresql::server::default_connect_settings,
  Enum['present', 'absent'] $ensure            = 'present',
  String                    $group             = $postgresql::server::group,
  Stdlib::Absolutepath      $psql_path         = $postgresql::server::psql_path,
  Optional[String]          $target_role       = undef,
  String[1]                 $instance          = 'main',
) {
  $version = pick($connect_settings['DBVERSION'],postgresql::default('version'))
  $port_override = pick($connect_settings['PGPORT'], $port)

  if (versioncmp($version, '9.6') == -1) {
    fail 'Default_privileges is only useable with PostgreSQL >= 9.6'
  }

  case $ensure {
    default: {
      # default is 'present'
      $sql_command = 'ALTER DEFAULT PRIVILEGES%s%s GRANT %s ON %s TO "%s"'
      $unless_is = true
    }
    'absent': {
      $sql_command = 'ALTER DEFAULT PRIVILEGES%s%s REVOKE %s ON %s FROM "%s"'
      $unless_is = false
    }
  }

  if $target_role {
    $_target_role = " FOR ROLE ${target_role}"
    $_check_target_role = "/${target_role}"
  } else {
    $_target_role = ''
    $_check_target_role = ''
  }

  if $schema != '' {
    $_schema = " IN SCHEMA ${schema}"
    $_check_schema = " AND nspname = '${schema}'"
  } else {
    $_schema = ''
    $_check_schema = ' AND nspname IS NULL'
  }

  ## Munge the input values
  $_object_type = upcase($object_type)
  $_privilege   = upcase($privilege)
  $_privileges  = $_privilege.split(',').map |$p| { $p.strip }

  # Map each privilege to its aclitem letters, see the PostgreSQL docs on privileges
  case $_object_type {
    # Routines and functions ends up with the same definition
    Pattern[
      /^ROUTINES$/,
      /^FUNCTIONS$/,
    ]: {
      $_privilege_map = {
        'ALL'     => 'X',
        'EXECUTE' => 'X',
      }
      $_check_type = 'f'
    }
    'SEQUENCES': {
      $_privilege_map = {
        'ALL'    => 'rwU',
        'SELECT' => 'r',
        'UPDATE' => 'w',
        'USAGE'  => 'U',
      }
      $_check_type = 'S'
    }
    'TABLES': {
      # Some platforms report legacy 9.x versions without the dot, e.g. '96'.
      $_version = regsubst($version, '^9(\d)$', '9.\1')
      # PostgreSQL 17 added the MAINTAIN privilege ('m'), which ALL includes.
      $_privilege_map = {
        'ALL'        => versioncmp($_version, '17') ? { -1 => 'arwdDxt', default => 'arwdDxtm' },
        'DELETE'     => 'd',
        'INSERT'     => 'a',
        'REFERENCES' => 'x',
        'SELECT'     => 'r',
        'TRIGGER'    => 't',
        'TRUNCATE'   => 'D',
        'UPDATE'     => 'w',
      }
      $_check_type = 'r'
    }
    'TYPES': {
      $_privilege_map = {
        'ALL'   => 'U',
        'USAGE' => 'U',
      }
      $_check_type = 'T'
    }
    'SCHEMAS': {
      if (versioncmp($version, '10') == -1) {
        fail 'Default_privileges on schemas is only supported on PostgreSQL >= 10.0'
      }
      if $schema != '' {
        fail('Cannot alter default schema permissions within a schema')
      }
      $_privilege_map = {
        'ALL'    => 'UC',
        'USAGE'  => 'U',
        'CREATE' => 'C',
      }
      $_check_type = 'n'
    }
    default: {
      fail("Missing privilege validation for object type ${_object_type}")
    }
  }

  $_check_privilege = $_privileges.map |$p| {
    $_privilege_map[$p].lest || { fail('Illegal value for $privilege parameter') }
  }.join('').split('').unique.join('')

  $_unless = $ensure ? {
    'absent' => "SELECT 1 WHERE NOT EXISTS (SELECT * FROM pg_default_acl AS da LEFT JOIN pg_namespace AS n ON da.defaclnamespace = n.oid WHERE '\"%s\"=%s%s' = ANY (defaclacl)%s and defaclobjtype = '%s')", # lint:ignore:140chars
    default  => "SELECT 1 WHERE EXISTS (SELECT * FROM pg_default_acl AS da LEFT JOIN pg_namespace AS n ON da.defaclnamespace = n.oid WHERE '\"%s\"=%s%s' = ANY (defaclacl)%s and defaclobjtype = '%s')", # lint:ignore:140chars
  }

  $unless_cmd = sprintf($_unless, $role, $_check_privilege, $_check_target_role, $_check_schema, $_check_type)
  $grant_cmd = sprintf($sql_command, $_target_role, $_schema, $_privileges.join(','), $_object_type, $role)

  postgresql_psql { "default_privileges:${name}":
    command          => $grant_cmd,
    db               => $db,
    port             => $port_override,
    connect_settings => $connect_settings,
    psql_user        => $psql_user,
    psql_group       => $group,
    psql_path        => $psql_path,
    unless           => $unless_cmd,
    environment      => 'PGOPTIONS=--client-min-messages=error',
    instance         => $instance,
  }

  if defined(Postgresql::Server::Role[$role]) {
    Postgresql::Server::Role[$role] -> Postgresql_psql["default_privileges:${name}"]
  }

  if defined(Postgresql::Server::Database[$db]) {
    Postgresql::Server::Database[$db] -> Postgresql_psql["default_privileges:${name}"]
  }
}
