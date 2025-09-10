# Security Policy

## Supported Versions

We actively maintain security updates for the following versions of HomeChat:

| Version | Supported          |
| ------- | ------------------ |
| main    | :white_check_mark: |

## Reporting a Vulnerability

We take security vulnerabilities seriously. If you discover a security vulnerability within HomeChat, please follow these guidelines:

### How to Report

1. **DO NOT** create a public GitHub issue for security vulnerabilities
2. Send an email to the maintainer with details about the vulnerability
3. Include the following information in your report:
   - Description of the vulnerability
   - Steps to reproduce the issue
   - Potential impact assessment
   - Any suggested fixes or mitigation strategies

### What to Expect

- **Acknowledgment**: We will acknowledge receipt of your vulnerability report within 48 hours
- **Assessment**: We will assess the vulnerability and determine its severity within 5 business days
- **Updates**: We will keep you informed of our progress on resolving the issue
- **Resolution**: We aim to resolve critical vulnerabilities within 7 days and other vulnerabilities within 30 days
- **Disclosure**: We will work with you on responsible disclosure timing

### Vulnerability Assessment Criteria

We use the following severity levels:

- **Critical**: Vulnerabilities that allow remote code execution or unauthorized access to sensitive data
- **High**: Vulnerabilities that could lead to privilege escalation or data exposure
- **Medium**: Vulnerabilities that could be exploited under specific conditions
- **Low**: Vulnerabilities with minimal security impact

## Security Measures

HomeChat implements several security measures:

### Automated Security Scanning
- **Brakeman**: Static analysis for Rails security vulnerabilities
- **Bundle Audit**: Ruby gem vulnerability scanning
- **CodeQL**: Comprehensive code analysis for security issues  
- **Dependabot**: Automated dependency updates for security patches
- **Dependency Review**: Security assessment of new dependencies in PRs

### Application Security
- Content Security Policy (CSP) headers
- Secure session configuration
- Input validation and sanitization
- SQL injection prevention
- Cross-Site Scripting (XSS) protection

### Infrastructure Security
- Secure deployment practices
- Regular security updates
- Environment variable protection
- Secure communication protocols

## Security Best Practices for Contributors

If you're contributing to HomeChat, please follow these security best practices:

1. **Never commit secrets**: API keys, passwords, or other sensitive data
2. **Validate input**: Always validate and sanitize user input
3. **Use parameterized queries**: Prevent SQL injection attacks
4. **Follow secure coding practices**: Reference OWASP guidelines
5. **Keep dependencies updated**: Regularly update gems and packages
6. **Test security features**: Include security testing in your contributions

## Security Contact

For security-related questions or to report vulnerabilities, please contact the project maintainer.

Thank you for helping keep HomeChat secure!