# frozen_string_literal: true

require 'spec_helper_acceptance'

describe 'postgresql::server::pg_ident_rule' do
  let(:pp) do
    <<-MANIFEST.unindent
      class { 'postgresql::server': }

      user { 'ident_os_user':
        ensure => present,
      }

      postgresql::server::role { 'ident_db_user': }

      postgresql::server::pg_ident_rule { 'map os user to db user':
        map_name          => 'testmap',
        system_username   => 'ident_os_user',
        database_username => 'ident_db_user',
      }

      postgresql::server::pg_hba_rule { 'local access via ident map':
        type        => 'local',
        database    => 'postgres',
        user        => 'ident_db_user',
        auth_method => 'peer',
        auth_option => 'map=testmap',
        order       => 1,
      }
    MANIFEST
  end

  it 'allows the mapped OS user to connect as the database user' do
    idempotent_apply(pp)

    psql('--username=ident_db_user --command="SELECT current_user" postgres', 'ident_os_user') do |r|
      expect(r.stdout).to match(%r{ident_db_user})
      expect(r.stderr).to eq('')
    end
  end
end
