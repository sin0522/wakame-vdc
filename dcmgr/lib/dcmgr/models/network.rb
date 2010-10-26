# -*- coding: utf-8 -*-

module Dcmgr::Models
  # Network definitions in the DC.
  class Network < BaseNew

    inheritable_schema do
      String :name, :size=>20, :null=>false
      String :ipv4, :null=>false
      String :netmask, :null=>false
      String :gw, :null=>false
      Text :description
      index :name, {:unique=>true}
    end
    with_timestamps

    many_to_one :host_pool

    def validate
      super
    end

    def to_hash
      values.dup.merge({:description=>description.to_s})
    end
    
  end
end