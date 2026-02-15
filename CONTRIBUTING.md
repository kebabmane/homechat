# Contributing to HomeChat

Thank you for your interest in contributing to HomeChat! This guide will help you get started.

## Code of Conduct

Be respectful, inclusive, and constructive. We welcome contributors of all experience levels.

## Getting Started

### Prerequisites

- Ruby 3.3+
- Node.js 18+ (for Tailwind CSS)
- SQLite 3
- Git

### Development Setup

1. **Fork and clone the repository**

   ```bash
   git clone https://github.com/YOUR_USERNAME/homechat.git
   cd homechat
   ```

2. **Install dependencies**

   ```bash
   bin/setup --skip-server
   ```

3. **Start the development server**

   ```bash
   bin/dev
   ```

4. **Run tests**

   ```bash
   bin/rails test
   ```

## How to Contribute

### Reporting Bugs

1. Check if the issue already exists in [GitHub Issues](https://github.com/kebabmane/homechat/issues)
2. If not, create a new issue with:
   - Clear, descriptive title
   - Steps to reproduce
   - Expected vs actual behavior
   - Environment details (OS, Ruby version, browser)
   - Screenshots if applicable

### Suggesting Features

1. Check existing issues and discussions
2. Create a new issue with the "enhancement" label
3. Describe the feature and its use case
4. Be open to feedback and iteration

### Pull Requests

1. **Create a branch**

   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes**

   - Write clear, readable code
   - Follow existing code style
   - Add tests for new functionality
   - Update documentation if needed

3. **Test your changes**

   ```bash
   bin/rails test
   bin/rubocop        # Check code style
   bin/brakeman       # Security scan
   ```

4. **Commit with clear messages**

   ```bash
   git commit -m "Add feature: description of what you added"
   ```

5. **Push and create PR**

   ```bash
   git push origin feature/your-feature-name
   ```

   Then create a Pull Request on GitHub.

## Development Guidelines

### Code Style

- Follow [Ruby Style Guide](https://rubystyle.guide/)
- Use RuboCop for linting: `bin/rubocop`
- ERB linting: `bundle exec erb_lint --lint-all`

### Testing

- Write tests for all new features and bug fixes
- Aim for meaningful test coverage
- Run the full test suite before submitting PRs

```bash
bin/rails test              # All tests
bin/rails test:models       # Model tests
bin/rails test:controllers  # Controller tests
bin/rails test:system       # System tests
COVERAGE=true bin/rails test  # With coverage report
```

### Security

- Never commit secrets or credentials
- Run security scans before submitting:

```bash
bin/brakeman                # Static analysis
bundle exec bundler-audit   # Dependency vulnerabilities
```

### Commit Messages

Use clear, descriptive commit messages:

- `Add feature: user profile avatars`
- `Fix: message ordering in channels`
- `Refactor: extract message validation logic`
- `Docs: update API authentication guide`

### Branch Naming

- `feature/description` — New features
- `fix/description` — Bug fixes
- `docs/description` — Documentation
- `refactor/description` — Code improvements

## Project Structure

```
homechat/
├── app/
│   ├── controllers/    # Request handling
│   ├── models/         # Business logic
│   ├── views/          # Templates
│   ├── channels/       # ActionCable channels
│   └── javascript/     # Stimulus controllers
├── config/             # Rails configuration
├── db/                 # Database migrations
├── docs/               # Documentation
├── test/               # Test files
└── public/             # Static files
```

## Testing Areas

### Priority Areas for Contributions

- **Test coverage**: We need more tests (current coverage ~24%)
- **Documentation**: Improve guides and API docs
- **Accessibility**: Improve keyboard navigation and screen reader support
- **Performance**: Optimize database queries and rendering

### What We're Looking For

- Bug fixes with test coverage
- Performance improvements with benchmarks
- Documentation improvements
- Accessibility enhancements

## Questions?

- Open a [Discussion](https://github.com/kebabmane/homechat/discussions)
- Check existing [Issues](https://github.com/kebabmane/homechat/issues)

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
