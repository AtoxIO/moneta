# Generated by generate.rb
require 'helper'

describe_juno "adapter_datamapper" do
  require 'dm-core'
  DataMapper.setup(:default, :adapter => :in_memory)
  def new_store
    Juno::Adapters::DataMapper.new(:setup => "sqlite3://#{make_tempdir}/adapter_datamapper")
  end

  include_context 'setup_store'
  it_should_behave_like 'null_stringkey_stringvalue'
  it_should_behave_like 'store_stringkey_stringvalue'
  it_should_behave_like 'returndifferent_stringkey_stringvalue'
  it_should_behave_like 'returndifferent_stringkey_objectvalue'
  it_should_behave_like 'null_stringkey_objectvalue'
  it_should_behave_like 'store_stringkey_objectvalue'
  it 'does not cross contaminate when storing' do
    first = Juno::Adapters::DataMapper.new(:setup => "sqlite3://#{make_tempdir}/datamapper-first")
    first.clear

    second = Juno::Adapters::DataMapper.new(:repository => :sample, :setup => "sqlite3://#{make_tempdir}/datamapper-second")
    second.clear

    first['key'] = 'value'
    second['key'] = 'value2'

    first['key'].should == 'value'
    second['key'].should == 'value2'
  end

  it 'does not cross contaminate when deleting' do
    first = Juno::Adapters::DataMapper.new(:setup => "sqlite3://#{make_tempdir}/datamapper-first")
    first.clear

    second = Juno::Adapters::DataMapper.new(:repository => :sample, :setup => "sqlite3://#{make_tempdir}/datamapper-second")
    second.clear

    first['key'] = 'value'
    second['key'] = 'value2'

    first.delete('key').should == 'value'
    first.key?('key').should == false
    second['key'].should == 'value2'
  end

end