class BoxTokensController < ActionController::Base
  before_action :authenticate_user!

  def temp
    token = BoxToken.for(BoxFolder.temp, 'item_upload', instance: true)
    render json: {folder: BoxFolder.temp, token: token.token, expire_at: token.expire_at}
  end
end