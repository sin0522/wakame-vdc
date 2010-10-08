# -*- coding: utf-8 -*-

module Dcmgr
  module Endpoints
    def self.define_error(class_name, status_code, &blk)
      c = Class.new(APIError)
      c.status_code(status_code)
      c.instance_eval(&blk) if blk
      self.const_set(class_name.to_sym, c)
    end
    
    class APIError < StandardError
      def self.status_code(code=nil)
        if code
          @status_code = code
        end
        @status_code || raise("@status_code for the class is not set")
      end
      
      def status_code
        self.class.status_code
      end
    end

    define_error(:UnknownUUIDResource, 404)
    define_error(:UnknownMember, 400)
    define_error(:InvalidCredentialHeaders, 400)
    define_error(:InvalidRequestCredentials, 400)
    define_error(:DisabledAccount, 403)
    define_error(:OperationNotPermitted, 403)
  end
end