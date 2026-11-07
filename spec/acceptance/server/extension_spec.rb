# frozen_string_literal: true

require 'spec_helper_acceptance'

describe 'postgresql::server::extension' do
  let(:pp) do
    <<-MANIFEST.unindent
      class { 'postgresql::server': }
      class { 'postgresql::server::contrib': }

      postgresql::server::database { 'extension_test': }

      postgresql::server::extension { 'pg_trgm':
        ensure   => #{ensure_value},
        database => 'extension_test',
        require  => Class['postgresql::server::contrib'],
      }
    MANIFEST
  end

  context 'with ensure => present' do
    let(:ensure_value) { 'present' }

    it 'creates the extension' do
      idempotent_apply(pp)
      psql(%(--command="SELECT extname FROM pg_extension WHERE extname = 'pg_trgm'" extension_test)) do |r|
        expect(r.stdout).to match(%r{pg_trgm})
        expect(r.stderr).to eq('')
      end
    end
  end

  context 'with ensure => absent' do
    let(:ensure_value) { 'absent' }

    it 'drops the extension' do
      idempotent_apply(pp)
      psql(%(--command="SELECT count(*) FROM pg_extension WHERE extname = 'pg_trgm'" extension_test)) do |r|
        expect(r.stdout).to match(%r{\b0\b})
        expect(r.stderr).to eq('')
      end
    end
  end
end
