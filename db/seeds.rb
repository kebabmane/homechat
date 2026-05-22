# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Create default admin user if no users exist
if User.count == 0
  admin_username = 'admin'
  admin_password = SecureRandom.hex(12)

  admin_user = User.create!(
    username: admin_username,
    password: admin_password,
    password_confirmation: admin_password,
    role: 'admin'
  )

  # Store credentials in a file accessible to the addon
  credentials_data = {
    username: admin_username,
    password: admin_password,
    created_at: Time.current.iso8601,
    message: "Default admin user created. Please change password after first login."
  }

  credentials_dir = Rails.env.production? ? Rails.root.join("storage") : Rails.root.join("tmp")
  FileUtils.mkdir_p(credentials_dir)
  credentials_file = credentials_dir.join("admin_credentials.json")
  File.write(credentials_file, JSON.pretty_generate(credentials_data))

  Rails.logger.info "Initial admin user created; credentials written to #{credentials_file}"
end
