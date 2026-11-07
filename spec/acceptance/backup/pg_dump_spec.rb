# frozen_string_literal: true

require 'spec_helper_acceptance'

describe 'postgresql::backup::pg_dump' do
  let(:pp) do
    <<-MANIFEST.unindent
      class { 'postgresql::server':
        backup_enable   => true,
        backup_provider => 'pg_dump',
        backup_options  => {
          db_user     => 'backupuser',
          db_password => 'backuppass',
          dir         => '/tmp/pgbackup',
          databases   => ['backup_test1', 'backup_test2'],
          format      => 'custom',
          manage_user => true,
        },
      }

      postgresql::server::database { ['backup_test1', 'backup_test2']: }
    MANIFEST
  end

  it 'installs the backup script and cron job' do
    idempotent_apply(pp)
    expect(file('/usr/local/sbin/pg_dump.sh')).to be_executable
    expect(run_shell('crontab -l -u root').stdout).to match(%r{/usr/local/sbin/pg_dump\.sh})
  end

  it 'dumps every database' do
    run_shell('rm -f /tmp/pgbackup_success && /usr/local/sbin/pg_dump.sh')
    expect(file('/tmp/pgbackup_success')).to exist
    result = run_shell('ls /tmp/pgbackup/*/')
    expect(result.stdout).to match(%r{backup_test1\.pgdump})
    expect(result.stdout).to match(%r{backup_test2\.pgdump})
  end
end
