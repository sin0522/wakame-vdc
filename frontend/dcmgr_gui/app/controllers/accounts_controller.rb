class AccountsController < ApplicationController
  def switch
    account_uuid = params[:accounts][:account_uuid]

    user = User.find(:uuid => @current_user.uuid)
    user.primary_account_id = account_uuid
    user.save

    redirect_to :root
  end
  
  def index

  end

  def update_settings
    account = params[:account]
    if account
      
      setting_params = {
        :time_zone => account[:time_zone],
        :locale => account[:locale],
      }

      User.update_settings(@current_user.id, setting_params)
    end
    redirect_to :action => 'index'
  end

  def password
    @error_message = ''
    if request.get?
      #nop
    elsif request.post?
      password =  params[:password]
      new_password = params[:new_password]
      confirm_password = params[:confirm_password]
      unless new_password == confirm_password
        @error_message = I18n.t('error_message.change_password1')
        return true 
      end

      user = User.find(:uuid => @current_user.uuid, :password => User.encrypt_password(password))
      if user
        user.password = User.encrypt_password(new_password)
        user.save
        redirect_to :action => 'index'
      else
        @error_message = I18n.t('error_message.change_password2')
      end
    end
  end
end
