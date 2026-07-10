#!/usr/bin/env ruby

require "digest"
require "json"
require "pathname"
require "yaml"

repo = Pathname(__dir__).join("../..").expand_path
bundle = repo.join("apps/codex-media-skills")
setup = bundle.join("setup.md").read
expected_files = {
  "nebula-image-gen/SKILL.md" => nil,
  "nebula-image-gen/agents/openai.yaml" => nil,
  "nebula-image-gen/references/api.md" => nil,
  "ark-video-gen/SKILL.md" => nil,
  "ark-video-gen/agents/openai.yaml" => nil,
  "ark-video-gen/references/api.md" => nil
}.freeze

actual_files = bundle.join("skills").glob("**/*").select(&:file?).map do |path|
  path.relative_path_from(bundle.join("skills")).to_s
end.sort
abort "Unexpected bundle files: #{actual_files.inspect}" unless actual_files == expected_files.keys.sort

manifest = setup.scan(/^((?:nebula-image-gen|ark-video-gen)\/\S+)\s+([0-9a-f]{64})$/).to_h
abort "Manifest paths do not match the bundle" unless manifest.keys.sort == expected_files.keys.sort

catalog = JSON.parse(repo.join("catalog.json").read)
entry = catalog.fetch("apps").find { |app| app["id"] == "codex-media-skills" }
abort "catalog.json is missing codex-media-skills" unless entry
abort "Catalog setup path does not exist" unless repo.join(entry.fetch("setup")).file?

%w[nebula-image-gen ark-video-gen].each do |name|
  skill = bundle.join("skills", name)
  skill.glob("**/*").each { |path| abort "Symlink is not allowed: #{path}" if path.symlink? }

  markdown = skill.join("SKILL.md").read
  frontmatter = markdown.match(/\A---\n(.*?)\n---/m)&.captures&.first
  abort "Invalid frontmatter: #{name}" unless frontmatter
  metadata = YAML.safe_load(frontmatter)
  abort "Invalid skill name: #{name}" unless metadata.keys.sort == %w[description name] && metadata["name"] == name

  interface = YAML.safe_load(skill.join("agents/openai.yaml").read).fetch("interface")
  required_fields = %w[display_name short_description default_prompt]
  abort "Incomplete UI metadata: #{name}" unless required_fields.all? { |field| interface[field].is_a?(String) && !interface[field].empty? }
  abort "default_prompt must mention $#{name}" unless interface["default_prompt"].include?("$#{name}")

  skill.glob("**/*").select(&:file?).each do |path|
    relative = path.relative_path_from(bundle.join("skills")).to_s
    digest = Digest::SHA256.file(path).hexdigest
    abort "Stale SHA-256 for #{relative}: #{digest}" unless manifest.fetch(relative) == digest
  end
end

raw_paths = setup.scan(%r{https://raw\.githubusercontent\.com/Likeusewin10/claude-app-setups/main/(\S+)}).flatten
expected_raw_paths = expected_files.keys.map { |path| "apps/codex-media-skills/skills/#{path}" }.sort
abort "Raw URL paths do not match the bundle" unless raw_paths.sort == expected_raw_paths
raw_paths.each do |raw_path|
  abort "Missing Raw target: #{raw_path}" unless repo.join(raw_path).file?
end

puts "codex-media-skills bundle is valid"
