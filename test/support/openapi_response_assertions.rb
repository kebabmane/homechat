# frozen_string_literal: true

require "json-schema"

module OpenapiResponseAssertions
  def assert_openapi_response(path, method: :get, status: "200")
    schema = openapi_response_schema(path, method, status)
    document = JSON.parse(response.body)
    errors = JSON::Validator.fully_validate(schema, document, errors_as_objects: true)

    assert_empty errors.map { |error| "#{error[:fragment]} #{error[:message]}" },
                 "Response for #{method.to_s.upcase} #{path} did not match OpenAPI #{status} schema"
  end

  private

  def openapi_response_schema(path, method, status)
    operation = openapi_spec.fetch("paths").fetch(path).fetch(method.to_s)
    schema = operation.fetch("responses").fetch(status).fetch("content").fetch("application/json").fetch("schema")

    normalize_openapi_schema(resolve_openapi_refs(schema))
  end

  def openapi_spec
    @openapi_spec ||= YAML.safe_load_file(Rails.root.join("api-contracts/openapi.yaml"), aliases: true)
  end

  def resolve_openapi_refs(value)
    case value
    when Hash
      if value.key?("$ref")
        resolve_openapi_ref(value.fetch("$ref"))
      else
        value.transform_values { |child| resolve_openapi_refs(child) }
      end
    when Array
      value.map { |child| resolve_openapi_refs(child) }
    else
      value
    end
  end

  def resolve_openapi_ref(ref)
    pointer = ref.delete_prefix("#/").split("/")
    target = pointer.reduce(openapi_spec) { |node, key| node.fetch(key) }

    resolve_openapi_refs(target)
  end

  def normalize_openapi_schema(value)
    case value
    when Hash
      normalized = value.each_with_object({}) do |(key, child), result|
        next if key == "example"

        result[key] = normalize_openapi_schema(child)
      end

      if normalized.delete("nullable") && normalized["type"].is_a?(String)
        normalized["type"] = [normalized["type"], "null"]
      end

      normalized
    when Array
      value.map { |child| normalize_openapi_schema(child) }
    else
      value
    end
  end
end
