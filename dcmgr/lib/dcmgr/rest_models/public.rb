module Dcmgr
  module RestModels::Public
    class FrontendServiceUser
      include Dcmgr::RestModels::Base
      public_name "frontend_service_users"
      set_protect false
      
      def authorize
        req = @orig_request
        fsuser = Dcmgr::FsuserAuthorizer.authorize(@orig_request)
      rescue Dcmgr::FsuserAuthorizer::NotAuthorized
        throw(:halt, [401, "Not authorized\n"])
      end

      def target_uuid(response=nil)
        if response and response.is_a? Hash and response.key?(:name)
          response[:name]
        else
          ""
        end
      end
      
      public_action :get, :myself do
        fsuser = authorize
        {:name=>fsuser}
      end

      public_action :get, :authorize do
        username, password = request[:_get_user], request[:_get_password]
        user = Models::User.find(:name=>username, :password=>password)
        if user
          {:id=>user.uuid, :name=>user.name}
        else
          nil
        end
      end
    end
    
    class Account
      include Dcmgr::RestModels::Base
      model Models::Account
      allow_keys :name, :memo, :enable, :contract_at

      public_action :get do
        find_all
      end

      public_action_withid :get do
        get
      end
      
      public_action_withid :put do
        update
      end
      
      public_action :post do
        account = create
        user.add_account(account)
        account
      end

      public_action_withid :delete do
        destroy
      end
    end

    class User
      include Dcmgr::RestModels::Base
      model Models::User
      allow_keys :name, :password, :enable, :email, :memo
      response_keys :uuid, :name, :enable, :email, :memo, :accounts

      public_action :post do
        create
      end
      
      public_action_withid :put do
        update
      end

      public_action :get, :myself do
        user
      end

      public_action_withid :get do
        get
      end

      public_action_withid :put, :add_account do
        target = Models::User[uuid]
        target.add_account(account)
        true
      end
      
      public_action :get do
        if request[:_get_same_accounts] == "true"
          user.accounts.map{|o|o.users}.flatten
        else
          find_all
        end
      end

      public_action_withid :delete do
        destroy
      end

      public_action_withid :put, :add_tag do
        target = Models::User[uuid]
        tag_uuid = request[:_get_tag]
        tag = Models::Tag[tag_uuid]

        Dcmgr.logger.debug(tag.id)
        Dcmgr.logger.debug(target.id)
        Dcmgr.logger.debug(uuid)
        Dcmgr.logger.debug(tag)

        Models::TagMapping.create(:tag_id=>tag.id,
                                  :target_type=>TagMapping::TYPE_USER,
                                  :target_id=>target.id)
        []
      end
    end

    class KeyPair
      include Dcmgr::RestModels::Base
      model Models::KeyPair
      allow_keys :user
      response_keys :uuid, :user, :public_key, :private_key

      public_action :post do
        create
      end

      public_action_withid :get do
        get
      end

      public_action_withid :delete do
        destroy
      end

      public_action :get do
        find_all
      end
    end

    class NameTag
      include Dcmgr::RestModels::Base
      model Models::Tag
      public_name 'name_tags'
      allow_keys :account, :name

      public_action :post do
        create
      end

      public_action_withid :delete do
        destroy
      end
    end

    class AuthTag
      include Dcmgr::RestModels::Base
      model Models::Tag
      public_name 'auth_tags'
      allow_keys :account, :name, :role

      public_action :post do
        req_hash = request
        req_hash.delete :id
        tags = req_hash.delete :tags

        obj = _create(req_hash)
        
        # tag mappings
        Dcmgr.logger.debug("tags")      
        Dcmgr.logger.debug(tags)
        tags.each {|tag_uuid|
          tag = Models::Tag[tag_uuid]
          Dcmgr.logger.debug(uuid)
          Dcmgr.logger.debug(tag)
          if tag
            Models::TagMapping.create(:tag_id=>obj.id,
                                      :target_type=>Models::TagMapping::TYPE_TAG,
                                      :target_id=>tag.id)
          end
        }
        
        obj
      end
      
      public_action_withid :delete do
        destroy
      end
    end

    class TagAttribute
      include Dcmgr::RestModels::Base
      model Models::TagAttribute
      allow_keys :body
      response_keys :body, [:uuid, proc {|o| o.tag.uuid}]

      public_action :get do
        find_all
      end

      public_action_withid :get do
        ret = nil
        if uuid
          tag = Models::Tag[uuid]
          ret = tag.tag_attribute
          unless ret
            ret = Models::TagAttribute.create(:tag=>tag,
                                              :body=>'')
          end
        end
        ret
      end

      public_action_withid :put do
        obj = Models::Tag[uuid].tag_attribute
        req_hash = request
        req_hash.delete :id
        allow_keys.each{|key|
          if key == :account # duplicate create
            obj.account = Models::Account[req_hash[key]]
          elsif key == :user
            
          else req_hash.key?(key)
            obj.send('%s=' % key, req_hash[key])
          end
        }
        obj.save
      end
    end

    class Instance
      include Dcmgr::RestModels::Base
      model Models::Instance
      allow_keys :account, :user, :physical_host, :image_storage,
      :need_cpus, :need_cpu_mhz, :need_memory

      response_keys :uuid, :account, :user, :tags, :physical_host, :image_storage,
      :need_cpus, :need_cpu_mhz, :need_memory, :status, :ip, :hv_agent
      [:tags, proc {|o| o.tags.map{|t| t.uuid}}]

      public_action :get do
        find_all{|find_params, request|
          unless request[:_get_location] and request[:_get_location_type]
            next
          end
          
          location_idx = Models::LocationGroup.index_by_name(request[:_get_location_type])
          unless location_idx
            raise InvalidParameterError, "unkown location type: #{request[:_get_location_type]}"
          end

          matched = false
          
          Dcmgr::Models::Tag.join(:tag_mappings, :tag_id=>:id).
          filter(:tag_mappings__target_type => Dcmgr::Models::TagMapping::TYPE_PHYSICAL_HOST_LOCATION).each{|tag|
            if Models::LocationGroup.match?(tag.name,
                                            request[:_get_location_type], request[:_get_location])
              tag.tag_mappings.each{|tm|
                if tm.target_type == TagMapping::TYPE_PHYSICAL_HOST_LOCATION
                  find_params << {:hv_agent_id=>
                    Models::PhysicalHost[tm.target_id].hv_agents.map{|hv| hv.id}
                  }
                  matched = true
                end
              }
            end
          }

          unless matched
            find_params << {:hv_agent_id=>-1}
          end
        }
      end
      
      public_action_withid :get do
        get
      end
      
      public_action_withid :put, :add_tag do
        instance = Models::Instance.find_by_uuid_with_user(uuid, user)
        unless instance
          raise RestModels::InvalidParameterError, "instance can't add tag"
        end

        tag_uuid = request[:_get_tag]
        tag = Models::Tag[tag_uuid]

        Models::TagMapping.create(:tag_id=>tag.id,
                                  :target_type=>Models::TagMapping::TYPE_INSTANCE,
                                  :target_id=>instance.id) if tag
        true
      end
      
      public_action_withid :put, :remove_tag do
        instance = Models::Instance.find_by_uuid_with_user(uuid, user)
        unless instance
          raise RestModels::InvalidParameterError, "instance can't remove tag"
        end

        tag_uuid = request[:_get_tag]
        tag = Models::Tag[tag_uuid]
        instance.remove_tag(tag.id) if tag
        true
      end
      
      public_action :post, nil, :action_name=>:run do
        req_hash = request
        req_hash.delete :id
        instance = nil

        Dcmgr.db.transaction do
          req_hash[:image_storage] = Models::ImageStorage[req_hash[:image_storage]]
          instance = _create(req_hash)

          instance.run
          instance.status = Models::Instance::STATUS_TYPE_RUNNING
          
          instance.save
        end
        instance
      end
      
      public_action_withid :get do
        get
      end
      
      public_action_withid :put do
        update
      end

      public_action_withid :delete, :action_name=>:terminate do
        destroy
      end

      public_action_withid :put, :reboot do
        instance = Models::Instance.find_by_uuid_with_user(uuid, user)
        unless instance
          raise RestModels::InvalidParameterError, "instance can't reboot"
        end

        Dcmgr.logger.debug("rebooting instance: #{instance.uuid}")

        instance.status = Models::Instance::STATUS_TYPE_TERMINATING
        instance.save

        instance.reboot
        true
      end

      public_action_withid :put, :shutdown do
        instance = Models::Instance.find_by_uuid_with_user(uuid, user)
        unless instance
          raise RestModels::InvalidParameterError, "instance can't shutdown"
        end
        Dcmgr.logger.debug("terminating instance: #{instance.uuid}")

        instance.status = Models::Instance::STATUS_TYPE_TERMINATING
        instance.save

        instance.shutdown

        true
      end

      public_action_withid :put, :snapshot do
        [] # TODO: snapshot action
      end
    end

    class HvController
      include Dcmgr::RestModels::Base
      model Models::HvController
      allow_keys :access_url

      public_action :post, nil, :action_name=>:run do
        request[:physical_host] = Models::PhysicalHost[request.delete(:physical_host)]
        _create(request)
      end

      public_action_withid :delete do
        destroy
      end
    end

    class ImageStorage
      include Dcmgr::RestModels::Base
      model Models::ImageStorage
      allow_keys :image_storage_host, :storage_url

      public_action :get do
        find_all
      end

      public_action :post do
        request[:image_storage_host] = Models::ImageStorageHost[request.delete(:image_storage_host)]
        _create(request)
      end

      public_action_withid :get do
        get
      end

      public_action_withid :delete do
        destroy
      end
    end

    class ImageStorageHost
      include Dcmgr::RestModels::Base
      model Models::ImageStorageHost
      allow_keys :name


      public_action :get do
        find_all
      end

      public_action :post do
        create
      end

      public_action_withid :get do
        get
      end

      public_action_withid :delete do
        destroy
      end
    end

    class PhysicalHost
      include Dcmgr::RestModels::Base
      model Models::PhysicalHost
      allow_keys :cpus, :cpu_mhz, :memory, :hypervisor_type
      
      public_action :get do
        find_all
      end

      public_action :post do
        create
      end

      public_action_withid :get do
        get
      end

      public_action_withid :delete do
        destroy
      end

      public_action_withid :put, :relate do
        user_uuid = request[:user]
        relate_user = Models::User[user_uuid]
        target = Models::PhysicalHost[uuid]
        target.relate_user_id = relate_user.id
        target.save
        target
      end
      
      public_action_withid :put, :remove_tag do
        target = Models::PhysicalHost[uuid]
        tag_uuid = request[:_get_tag]
        tag = Models::Tag[tag_uuid]
        target.remove_tag(tag) if tag
        []
      end
    end

    class Log
      include Dcmgr::RestModels::Base
      model Models::Log

      public_action :get do
        Models::Log.filter(:account_id=>account.id).all
      end

      def target_uuid(res=nil)
        model.to_s.split("::").last
      end
    end

    class AccountLog
      include Dcmgr::RestModels::Base
      model Models::AccountLog

      public_action :get do
        Models::AccountLog.filter(:account_id=>account.id).all
      end
    end

    class LocationGroup
      include Dcmgr::RestModels::Base
      model Models::LocationGroup
      allow_keys :name
      
      public_action :get do
        Models::LocationGroup.all
      end
    end
  end
end