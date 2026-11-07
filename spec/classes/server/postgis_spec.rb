# frozen_string_literal: true

require 'spec_helper'

describe 'postgresql::server::postgis' do
  include_examples 'Debian 11'
  let :pre_condition do
    "class { 'postgresql::server': }"
  end

  describe 'with parameters' do
    let(:params) do
      {
        package_name: 'mypackage',
        package_ensure: 'absent'
      }
    end

    it 'creates package with correct params' do
      expect(subject).to contain_package('postgresql-postgis').with(ensure: 'absent',
                                                                    name: 'mypackage',
                                                                    tag: 'puppetlabs-postgresql')
    end
  end

  describe 'with no parameters' do
    it 'creates package with postgresql tag' do
      expect(subject).to contain_package('postgresql-postgis').with(tag: 'puppetlabs-postgresql')
    end
  end

  # https://github.com/puppetlabs/puppetlabs-postgresql/issues/1522
  describe 'default package name' do
    {
      'Debian 12' => { version: '15', package: 'postgresql-15-postgis-3' },
      'RedHat 8' => { version: '16', package: 'postgis34_16' },
      'Fedora 33' => { version: '13', package: 'postgis' },
    }.each do |os, expected|
      context "on #{os} with PostgreSQL #{expected[:version]}" do
        include_examples os

        let :pre_condition do
          <<-PUPPET
          class { 'postgresql::globals':
            version             => '#{expected[:version]}',
            manage_package_repo => true,
          }
          class { 'postgresql::server': }
          PUPPET
        end

        it { is_expected.to contain_package('postgresql-postgis').with_name(expected[:package]) }
      end
    end

    context 'on RedHat 8 with an explicit postgis_version' do
      include_examples 'RedHat 8'

      let :pre_condition do
        <<-PUPPET
        class { 'postgresql::globals':
          version             => '16',
          postgis_version     => '3.5.2',
          manage_package_repo => true,
        }
        class { 'postgresql::server': }
        PUPPET
      end

      it { is_expected.to contain_package('postgresql-postgis').with_name('postgis35_16') }
    end
  end
end
