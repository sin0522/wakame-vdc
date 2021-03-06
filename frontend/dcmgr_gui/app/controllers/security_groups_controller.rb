class SecurityGroupsController < ApplicationController
  respond_to :json
  
  def index
  end
  
  # security_groups/show/1.json
  def list
    data = {
      :start => params[:start].to_i - 1,
      :limit => params[:limit]
    }
    @security_group = DcmgrResource::SecurityGroup.list(data)
    respond_with(@security_group[0],:to => [:json])
  end
  
  # security_groups/detail/s-000001.json
  def show
    uuid = params[:id]
    @security_group = DcmgrResource::SecurityGroup.show(uuid)
    respond_with(@security_group,:to => [:json])
  end

  def create
    data = {
      :description => params[:description],
      :rule => params[:rule]
    }
    @security_group = DcmgrResource::SecurityGroup.create(data)
    render :json => @security_group
  end
  
  def destroy
    uuid = params[:id]
    @security_group = DcmgrResource::SecurityGroup.destroy(uuid)
    render :json => @security_group    
  end
  
  def update
    uuid = params[:id]
    data = {
      :description => params[:description],
      :rule => params[:rule]
    }
    @security_group = DcmgrResource::SecurityGroup.update(uuid,data)
    render :json => @security_group    
  end
  
  def show_groups
    @security_group = DcmgrResource::SecurityGroup.list
    respond_with(@security_group[0],:to => [:json])
  end
  
  def total
   total_resource = DcmgrResource::SecurityGroup.total_resource
   render :json => total_resource
  end
end
