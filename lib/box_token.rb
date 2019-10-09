class BoxToken < ActiveRecord::Base
  def self.token
    Boxr.get_enterprise_token(private_key: ENV['BOX_PRIVATE_KEY'],
                              private_key_password: ENV['BOX_PASSPHRASE'],
                              public_key_id: ENV['BOX_PUBLIC_KEY_ID'],
                              enterprise_id: ENV['BOX_ENTERPRISE_ID'],
                              client_id: ENV['BOX_CLIENT_ID'],
                              client_secret: ENV['BOX_CLIENT_SECRET'])
  end

  def self.for(folder, rights = 'base_preview', instance: false)
    res = self.find_by(folder: folder, rights: rights)
    unless res
      res = self.create!(folder: folder, rights: rights)
    end
    instance ? res : res.token
  end

  def self.root
    self.for(BoxFolder.root, nil, instance: true)
  end

  def self.client
    root.client
  end

  def token
    ensure_token_valid
    access_token
  end

  def client
    Boxr::Client.new(token)
  end

  private

  def ensure_token_valid
    unless token_valid?
      t = generate_token
      self.access_token = t.access_token
      self.expire_at = DateTime.now + t.expires_in.seconds - 15.minutes
      self.save!
    end
  end

  def generate_token
    if rights
      Boxr.exchange_token(BoxToken.root.token, rights, resource_id: folder, resource_type: :folder)
    else
      self.class.token
    end
  end

  def token_valid?
    if access_token && expire_at
      Time.now < expire_at
    else
      false
    end
  end
end