namespace :ops do
  desc "Backup SQLite database and storage (usage: rake ops:backup[dest_dir])"
  task :backup, [:dest] => :environment do |t, args|
    require 'fileutils'
    dest = args[:dest] || "backups/#{Time.now.strftime('%Y-%m-%d_%H%M%S')}"
    FileUtils.mkdir_p(dest)

    db = ActiveRecord::Base.connection_db_config.database
    abort("Only SQLite backups are supported. Current DB: #{db}") unless db && db.end_with?(".sqlite3")

    puts "Backing up DB: #{db} -> #{dest}"
    FileUtils.cp(db, File.join(dest, File.basename(db)))

    storage = Rails.root.join('storage')
    if Dir.exist?(storage)
      puts "Backing up storage -> #{dest}/storage"
      FileUtils.mkdir_p(File.join(dest, 'storage'))
      FileUtils.cp_r(Dir[storage.join('**', '*')], File.join(dest, 'storage'))
    else
      puts "No storage directory; skipping"
    end
    puts "Backup complete at #{dest}"
  end
end

