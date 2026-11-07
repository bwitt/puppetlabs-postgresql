# frozen_string_literal: true

require 'spec_helper'

describe 'postgresql::default' do
  let(:facts) do
    {
      'os' => {
        'family' => 'Debian',
        'name'   => 'Debian',
        'release' => {
          'full'  => '11.7',
          'major' => '11',
          'minor' => '7',
        }
      }
    }
  end

  let(:pre_condition) do
    <<~PP
    class { 'postgresql::server':
    }
    PP
  end

  # parameter in params.pp only
  it { is_expected.to run.with_params('port').and_return(5432) }

  # parameter in globals.pp only
  it { is_expected.to run.with_params('default_connect_settings').and_return({}) }

  it { is_expected.to run.with_params('password_encryption').and_return('md5') }

  it { is_expected.to run.with_params('a_parameter_that_does_not_exist').and_raise_error(Puppet::ParseError, %r{pick\(\): must receive at least one non empty value}) }

  context 'with overridden values' do
    let(:pre_condition) do
      <<~PUPPET
      class { 'postgresql::globals':
        password_encryption => 'scram-sha-256',
      }
      PUPPET
    end

    it { is_expected.to run.with_params('password_encryption').and_return('scram-sha-256') }
  end

  # https://github.com/puppetlabs/puppetlabs-postgresql/issues/1721
  context 'on Fedora' do
    { '41' => '16', '42' => '16', '43' => '18', '44' => '18', '45' => '18' }.each do |release, version|
      context "release #{release}" do
        let(:facts) do
          {
            'os' => {
              'family' => 'RedHat',
              'name' => 'Fedora',
              'release' => { 'full' => release, 'major' => release },
              'selinux' => { 'enabled' => false },
            },
            'service_provider' => 'systemd',
          }
        end

        it { is_expected.to run.with_params('version').and_return(version) }
      end
    end
  end
end
