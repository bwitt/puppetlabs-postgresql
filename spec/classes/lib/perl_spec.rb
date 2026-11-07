# frozen_string_literal: true

require 'spec_helper'

describe 'postgresql::lib::perl' do
  describe 'on redhat 8' do
    include_examples 'RedHat 8'

    it {
      expect(subject).to contain_package('perl-DBD-Pg').with(
        name: 'perl-DBD-Pg',
        ensure: 'present',
      )
    }
  end

  describe 'on debian 11' do
    include_examples 'Debian 11'

    it {
      expect(subject).to contain_package('perl-DBD-Pg').with(
        name: 'libdbd-pg-perl',
        ensure: 'present',
      )
    }
  end

  describe 'on FreeBSD' do
    let(:facts) do
      {
        os: { 'family' => 'FreeBSD', 'name' => 'FreeBSD', 'release' => { 'full' => '14.1', 'major' => '14' } },
        service_provider: 'freebsd'
      }
    end

    it { is_expected.to contain_package('perl-DBD-Pg').with_name('databases/p5-DBD-Pg') }

    context 'with plperl_package_name set in globals' do
      let(:pre_condition) { "class { 'postgresql::globals': plperl_package_name => 'custom-plperl' }" }

      it { is_expected.to contain_package('perl-DBD-Pg').with_name('databases/p5-DBD-Pg') }
    end

    context 'with perl_package_name set in globals' do
      let(:pre_condition) { "class { 'postgresql::globals': perl_package_name => 'custom-perl' }" }

      it { is_expected.to contain_package('perl-DBD-Pg').with_name('custom-perl') }
    end
  end
end
