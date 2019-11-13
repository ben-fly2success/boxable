class BoxToken < ActiveRecord::Base
  def self.token
    Boxr.get_enterprise_token(private_key: Boxable.private_key,
                              private_key_password: Boxable.private_key_password,
                              public_key_id: Boxable.public_key_id,
                              enterprise_id: Boxable.enterprise_id,
                              client_id: Boxable.client_id,
                              client_secret: Boxable.client_secret)
  end

  def self.for(resource_id, resource_type, rights = 'base_preview', instance: false)
    res = find_by(resource_id: resource_id, resource_type: resource_type, rights: rights) || create!(resource_id: resource_id, resource_type: resource_type, rights: rights)
    instance ? res : res.token
  end

  def self.root
    BoxFolder.root.token(instance: true)
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
      Boxr.exchange_token(BoxToken.root.token, rights, resource_id: resource_id, resource_type: resource_type.to_sym)
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