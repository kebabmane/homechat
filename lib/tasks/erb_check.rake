namespace :erb do
  desc "Check ERB files for syntax errors before linting"
  task :syntax_check do
    erb_files = Dir.glob("app/views/**/*.erb")
    errors = []
    
    erb_files.each do |file|
      begin
        erb_content = File.read(file)
        ERB.new(erb_content, trim_mode: '-').src
      rescue SyntaxError => e
        errors << "#{file}: #{e.message}"
      rescue => e
        errors << "#{file}: #{e.message}"
      end
    end
    
    if errors.any?
      puts "ERB Syntax Errors Found:"
      errors.each { |error| puts "  #{error}" }
      exit 1
    else
      puts "✅ All ERB files have valid syntax"
    end
  end
  
  desc "Check syntax then run ERB lint"
  task :check_and_lint do
    Rake::Task["erb:syntax_check"].invoke
    system("bundle exec erb_lint --lint-all")
  end
end