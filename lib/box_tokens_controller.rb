class BoxTokensController < ActionController::Base
  before_action :authenticate_user!

  def temp
    token = BoxFolder.temp.token_for('item_upload', instance: true)
    render json: {folder: BoxFolder.temp.folder_id, token: token.token, expire_at: token.expire_at}
  end
end