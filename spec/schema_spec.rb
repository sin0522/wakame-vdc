# -*- coding: utf-8 -*-

require File.dirname(__FILE__) + '/spec_helper'

describe Dcmgr::Schema do
  it "should drop all tables" do
    Dcmgr::Schema.drop!
    Dcmgr::Schema.models.each{|model|
      Dcmgr::Schema.table_exists?(model.table_name).should be_false
    }
  end
  
  it "should store initial data, by mysqldump" do
    Dcmgr::Schema.drop!
    Dcmgr::Schema.create!
    Dcmgr::Schema.initial_data
    
    Dcmgr::Schema.models.each{|model|
      if model == User
        User.count.should == 1
      elsif model == Tag
        Tag.count.should == 1
      else
        model.count.should == 0
      end
    }
  end
  
  it "should store sample data, by mysqldump" do
    Dcmgr::Schema.drop!
    Dcmgr::Schema.create!
    Dcmgr::Schema.load_data File.dirname(__FILE__) + '/../fixtures/sample_data.dump'
    
    Dcmgr::Schema.models.each{|model|
      next if [Instance, TagMapping, Log].include? model
      puts model
      model.count.should > 0
    }
  end
end

