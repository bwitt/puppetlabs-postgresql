# @summary This function pull default values from the `postgresql::server` class if it is declared, otherwise from the `params` class or `globals` class if the value is not present in `params`.
#
# @example
#   postgresql::default('variable')
#
function postgresql::default(
  String $parameter_name
) {
  include postgresql::params

  # Prefer the value set on postgresql::server, e.g. a custom port.
  # params inherits from globals, so it will also catch these variables.
  if defined(Class['postgresql::server']) {
    pick(getvar("postgresql::server::${parameter_name}"), getvar("postgresql::params::${parameter_name}"))
  } else {
    pick(getvar("postgresql::params::${parameter_name}"))
  }
}
