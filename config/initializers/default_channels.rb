# Create default channels on server startup
Rails.application.config.after_initialize do
  # Only run this in non-test environments and when ActiveRecord is available
  unless Rails.env.test? || !defined?(ActiveRecord::Base)
    begin
      # Ensure database is connected and tables exist
      if ActiveRecord::Base.connection.table_exists?('channels') && ActiveRecord::Base.connection.table_exists?('users')
        # Create default "home" channel if it doesn't exist
        home_channel = Channel.find_by(name: 'home')
        unless home_channel
          # Find an admin user or the first user to be the channel creator
          creator = User.where(role: 'admin').first || User.first

          if creator
            home_channel = Channel.create!(
              name: 'home',
              description: 'Default home channel for all users',
              channel_type: 'public',
              created_by: creator
            )

            # Add the creator to the home channel
            home_channel.add_member(creator)

            Rails.logger.info "✅ Default 'home' channel created successfully on server startup"
          else
            Rails.logger.warn "⚠️  No users found to create default home channel - will be created when first user is created"
          end
        end
      end
    rescue ActiveRecord::StatementInvalid, ActiveRecord::ConnectionNotEstablished => e
      # Database might not be ready yet - that's okay, we'll catch it next time
      Rails.logger.debug "Database not ready for default channel creation: #{e.message}"
    rescue => e
      Rails.logger.error "Error creating default home channel: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end
  end
end