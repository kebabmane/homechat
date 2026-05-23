namespace :erb_lint do
  desc "Run ERB lint on all templates"
  task check: :environment do
    system("bundle exec erb_lint --lint-all")
  end

  desc "Run ERB lint with auto-correction"
  task autocorrect: :environment do
    system("bundle exec erb_lint --lint-all --autocorrect")
  end
end
