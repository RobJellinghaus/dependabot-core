# frozen_string_literal: true

require "dependabot/file_fetchers"
require "dependabot/file_fetchers/base"

module Dependabot
  module Composer
    class FileFetcher < Dependabot::FileFetchers::Base
      require_relative "file_fetcher/path_dependency_builder"

      def self.required_files_in?(filenames)
        filenames.include?("composer.json")
      end

      def self.required_files_message
        "Repo must contain a composer.json."
      end

      private

      def fetch_files
        fetched_files = []
        fetched_files << composer_json
        fetched_files << composer_lock if composer_lock
        fetched_files << auth_json if auth_json
        fetched_files += path_dependencies
        fetched_files
      end

      def composer_json
        @composer_json ||= fetch_file_from_host("composer.json")
      end

      def composer_lock
        return @composer_lock if @composer_lock_lookup_attempted

        @composer_lock_lookup_attempted = true
        @composer_lock ||= fetch_file_if_present("composer.lock")
      end

      # Note: This is fetched but currently unused
      def auth_json
        @auth_json ||= fetch_file_if_present("auth.json")&.
                       tap { |f| f.support_file = true }
      end

      def path_dependencies
        @path_dependencies ||=
          begin
            composer_json_files = []
            unfetchable_deps = []

            path_sources.each do |path|
              directories = path.end_with?("*") ? expand_path(path) : [path]

              directories.each do |dir|
                file = File.join(dir, "composer.json")

                begin
                  composer_json_files << fetch_file_with_root_fallback(file)
                rescue Dependabot::DependencyFileNotFound
                  unfetchable_deps << path
                end
              end
            end

            composer_json_files += build_unfetchable_deps(unfetchable_deps)

            # Mark the path dependencies as support files - we don't currently
            # parse or update them.
            composer_json_files.tap do |files|
              files.each { |f| f.support_file = true }
            end
          end
      end

      def path_sources
        @path_sources ||=
          JSON.parse(composer_json.content).
          fetch("repositories", []).
          select { |details| details["type"] == "path" }.
          map { |details| details["url"] }
      rescue JSON::ParserError
        raise Dependabot::DependencyFileNotParseable, composer_json.path
      end

      def build_unfetchable_deps(unfetchable_deps)
        unfetchable_deps.map do |path|
          PathDependencyBuilder.new(
            path: path,
            directory: directory,
            lockfile: composer_lock
          ).dependency_file
        end.compact
      end

      def expand_path(path)
        repo_contents(dir: path.gsub(/\*$/, "")).
          select { |file| file.type == "dir" }.
          map { |f| path.gsub(/\*$/, f.name) }
      rescue Octokit::NotFound, Gitlab::Error::NotFound
        # If there's no lockfile, or if none of the dependencies are path
        # dependencies, then we can ignore failures to find path deps
        return [] unless composer_lock&.content&.include?('"path"')

        # Otherwise, we don't know what to do. For now, just raise. If we see
        # this in the wild we can make a call on the correct handling
        raise if directory == "/"

        # If the directory isn't found at the full path, try looking for it
        # at the root of the repository.
        depth = directory.gsub(%r{^/}, "").gsub(%r{/$}, "").split("/").count
        dir = "../" * depth + path.gsub(/\*$/, "").gsub(/^\.*/, "")

        repo_contents(dir: dir).
          select { |file| file.type == "dir" }.
          map { |f| path.gsub(/\*$/, f.name) }
      end

      def fetch_file_with_root_fallback(filename)
        path = Pathname.new(File.join(directory, filename)).cleanpath.to_path

        begin
          fetch_file_from_host(filename, fetch_submodules: true)
        rescue Dependabot::DependencyFileNotFound
          # If the file isn't found at the full path, try looking for it
          # without considering the directory (i.e., check if the path should
          # have been relevative to the root of the repository).
          cleaned_filename = filename.gsub(/^\./, "")
          cleaned_filename = Pathname.new(cleaned_filename).cleanpath.to_path

          DependencyFile.new(
            name: Pathname.new(filename).cleanpath.to_path,
            content: _fetch_file_content(cleaned_filename),
            directory: directory,
            type: "file"
          )
        end
      rescue Octokit::NotFound, Gitlab::Error::NotFound
        raise Dependabot::DependencyFileNotFound, path
      end
    end
  end
end

Dependabot::FileFetchers.register("composer", Dependabot::Composer::FileFetcher)
