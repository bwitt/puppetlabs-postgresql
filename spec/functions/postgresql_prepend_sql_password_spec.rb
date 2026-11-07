# frozen_string_literal: true

require 'spec_helper'

describe 'postgresql::prepend_sql_password' do
  it { is_expected.to run.with_params('mypassword').and_return("ENCRYPTED PASSWORD 'mypassword'") }
  it { is_expected.to run.with_params('new-pa$s').and_return("ENCRYPTED PASSWORD 'new-pa$s'") }
  it { is_expected.to run.with_params("O'Brien").and_return("ENCRYPTED PASSWORD 'O''Brien'") }
end
