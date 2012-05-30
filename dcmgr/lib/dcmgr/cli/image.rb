# -*- coding: utf-8 -*-

module Dcmgr::Cli
  class Image < Base
    namespace :image
    M = Dcmgr::Models


    class AddOperation < Base
      namespace :add

      desc "local backup_object_id [options]", "Register local store machine image"
      method_option :uuid, :type => :string, :desc => "The UUID for the new machine image"
      method_option :account_id, :type => :string, :required => true, :desc => "The UUID of the account that this machine image belongs to"
      method_option :arch, :type => :string, :default => 'x86_64', :desc => "The architecture for the new machine image. [#{M::HostNode::SUPPORTED_ARCH.join(', ')}]"
      method_option :is_public, :type => :boolean, :default => false, :desc => "A flag that determines whether the new machine image is public or not"
      method_option :description, :type => :string, :desc => "An arbitrary description of the new machine image"
      method_option :file_format, :type => :string, :default => "raw", :desc => "The file format for the new machine image"
      method_option :root_device, :type => :string, :desc => "The root device of image"
      #method_option :state, :type => :string, :default => "init", :desc => "The state for the new machine image"
      method_option :service_type, :type => :string, :default=>Dcmgr.conf.default_service_type, :desc => "Service type of the machine image. (#{Dcmgr.conf.service_types.keys.sort.join(', ')})"
      method_option :display_name, :type => :string, :required => true, :desc => "Display name of the machine image"
      def local(backup_object_id)
        UnknownUUIDError.raise(options[:account_id]) if M::Account[options[:account_id]].nil?
        UnsupportedArchError.raise(options[:arch]) unless M::HostNode::SUPPORTED_ARCH.member?(options[:arch])
        UnknownUUIDError.raise(backup_object_id) unless M::BackupObject[backup_object_id]
        
        fields = options.dup
        fields[:backup_object_id]=backup_object_id
        fields[:boot_dev_type]=M::Image::BOOT_DEV_LOCAL
        
        puts add(M::Image, fields)
      end

      desc "volume backup_object_id [options]", "Register volume store machine image."
      method_option :uuid, :type => :string, :desc => "The UUID for the new machine image."
      method_option :account_id, :type => :string, :required => true, :desc => "The UUID of the account that this machine image belongs to."
      method_option :arch, :type => :string, :default => 'x86_64', :desc => "The architecture for the new machine image. [#{M::HostNode::SUPPORTED_ARCH.join(', ')}]"
      method_option :is_public, :type => :boolean, :default => false, :desc => "A flag that determines whether the new machine image is public or not."
      method_option :description, :type => :string, :desc => "An arbitrary description of the new machine image"
      method_option :file_format, :type => :string, :default => "raw", :desc => "The file format for the new machine image"
      method_option :root_device, :type => :string, :desc => "The root device of image"
      #method_option :state, :type => :string, :default => "init", :desc => "The state for the new machine image"
      method_option :service_type, :type => :string, :default=>Dcmgr.conf.default_service_type, :desc => "Service type of the machine image. (#{Dcmgr.conf.service_types.keys.sort.join(', ')})"
      method_option :display_name, :type => :string, :required => true, :desc => "Display name of the machine image"
      def volume(backup_object_id)
        UnknownUUIDError.raise(options[:account_id]) if M::Account[options[:account_id]].nil?
        UnsupportedArchError.raise(options[:arch]) unless M::HostNode::SUPPORTED_ARCH.member?(options[:arch])
        UnknownUUIDError.raise(backup_object_id) if M::BackupObject[backup_object_id].nil?
        
        #TODO: Check if :state is a valid state
        fields = options.dup
        fields[:boot_dev_type]=M::Image::BOOT_DEV_SAN
        fields[:backup_object_id]=backup_object_id
        
        puts add(M::Image, fields)
      end
      
      protected
      def self.basename
        "vdc-manage #{Image.namespace} #{self.namespace}"
      end
    end

    register AddOperation, 'add', "add IMAGE_TYPE [options]", "Add image metadata [#{AddOperation.tasks.keys.join(', ')}]"

    desc "modify UUID [options]", "Modify a registered machine image"
    method_option :description, :type => :string, :desc => "An arbitrary description of the machine image"
    method_option :state, :type => :string, :default => "init", :desc => "The state for the machine image"
    method_option :account_id, :type => :string, :desc => "The UUID of the account that this machine image belongs to."
    method_option :arch, :type => :string, :default => 'x86_64', :desc => "The architecture for the new machine image. [#{M::HostNode::SUPPORTED_ARCH.join(', ')}]"
    method_option :is_public, :type => :boolean,  :desc => "A flag that determines whether the new machine image is public or not."
    method_option :description, :type => :string, :desc => "An arbitrary description of the new machine image"
    method_option :file_format, :type => :string, :default => "raw", :desc => "The file format for the new machine image"
    method_option :root_device, :type => :string, :desc => "The root device of image"
    method_option :service_type, :type => :string, :desc => "Service type of the machine image. (#{Dcmgr.conf.service_types.keys.sort.join(', ')})"
    method_option :display_name, :type => :string, :desc => "Display name of the machine image"
    method_option :backup_object_id, :type => :string, :desc => "Backup object for the machine image"
    def modify(uuid)
      UnknownUUIDError.raise(uuid) if M::Image[uuid].nil?
      UnknownUUIDError.raise(options[:account_id]) if M::Account[options[:account_id]].nil?
      UnsupportedArchError.raise(options[:arch]) unless M::HostNode::SUPPORTED_ARCH.member?(options[:arch])

      fields = options.dup

      super(M::Image,uuid,fields)
    end

    desc "del IMAGE_ID", "Delete registered machine image"
    def del(image_id)
      UnknownUUIDError.raise(image_id) if M::Image[image_id].nil?
      super(M::Image, image_id)
    end

    desc "show [IMAGE_ID]", "Show list of machine image and details"
    def show(uuid=nil)
      if uuid
        img = M::Image[uuid] || UnknownUUIDError.raise(uuid)
        print ERB.new(<<__END, nil, '-').result(binding)
UUID: <%= img.canonical_uuid %>
Account ID: <%= img.account_id %>
Boot Type: <%= img.boot_dev_type == M::Image::BOOT_DEV_LOCAL ? 'local' : 'volume'%>
Arch: <%= img.arch %>
Is Public: <%= img.is_public %>
State: <%= img.state %>
Service Type: <%= img.service_type %>
Features:
<%= img.features %>
<%- if img.description -%>
Description:
  <%= img.description %>
<%- end -%>
__END
      else
        cond = {}
        imgs = M::Image.filter(cond).all
        print ERB.new(<<__END, nil, '-').result(binding)
<%- imgs.each { |row| -%>
<%= row.canonical_uuid %>\t<%= row.boot_dev_type == M::Image::BOOT_DEV_LOCAL ? 'local' : 'volume'%>\t<%= row.arch %>
<%- } -%>
__END
      end
    end

    desc "features IMAGE_ID", "Set features attribute to the image"
    method_option :virtio, :type => :boolean, :desc => "Virtio ready image."
    def features(uuid)
      img = M::Image[uuid]
      UnknownUUIDError.raise(uuid) if img.nil?

      if options[:virtio]
        img.set_feature(:virtio, options[:virtio])
      end
      img.save_changes
    end
    
  end
end
