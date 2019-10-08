class BoxToken < ActiveRecord::Base
  def client
    ensure_token_valid
    Boxr::Client.new(self.token)
  end

  def self.token
    Boxr.get_enterprise_token(private_key: ENV['BOX_PRIVATE_KEY'],
                              private_key_password: ENV['BOX_PASSPHRASE'],
                              public_key_id: ENV['BOX_PUBLIC_KEY_ID'],
                              enterprise_id: ENV['BOX_ENTERPRISE_ID'],
                              client_id: ENV['BOX_CLIENT_ID'],
                              client_secret: ENV['BOX_CLIENT_SECRET'])
  end

  scope :root_scope, lambda {
    where(folder: ENV['BOX_ROOT_FOLDER'])
  }

  def self.root
    res = root_scope
    raise 'No box root folder in environment. Try running rake box:install to update it.' if res.empty?
    res.first
  end

  private

  def ensure_token_valid
    puts "VALID: #{token_valid?}"
    unless token_valid?
      t = self.class.token
      self.token = t.access_token
      self.expire_at = DateTime.now + t.expires_in.seconds - 15.minutes
      self.save!
    end
  end

  def token_valid?
    if token && expire_at
      Time.now < expire_at
    else
      false
    end
  end
end