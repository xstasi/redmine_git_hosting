module GitHosting
	class GitoliteConfig
		@admin_user_key = nil
		@path = nil

		
		def initialize file_path
			@path = file_path
			load_repos
			@admin_user_key = get_admin_user_key
		end

		def save
			@original_content = content
			File.open(@path, "w") do |f|
				f.puts @original_content
			end
			ensure_config_included
		end

		def add_write_user repo_name, users
			repository(repo_name).add "RW+", users
		end

		def set_write_user repo_name, users
			repository(repo_name).set "RW+", users
		end

		def add_read_user repo_name, users
			repository(repo_name).add "R", users
		end

		def set_read_user repo_name, users
			repository(repo_name).set "R", users
		end

		def delete_repo repo_name
			@repositories.delete(repo_name)
		end

		def rename_repo old_name, new_name
			if @repositories.has_key?(old_name)
				perms = @repositories.delete(old_name)
				@repositories[new_name] = perms
			end
		end

		def changed?
			@original_content != content
		end

		def all_repos
			repos={}
			@repositories.each do |repo, rights|
				repos[repo] = 1
			end
			return repos
		end

		def ensure_config_included
			load_config_file = @path.gsub(/^.*\//, "")
			if(load_config_file != "gitolite.conf")
				
				include_found = false
				gitolite_path = @path.gsub(/[^\/]*$/,"") + "gitolite.conf"
				gitolite_conf_lines = []
				File.open(gitolite_path).each_line do |line|
					gitolite_conf_lines.push(line)
					include_found = line.match(/^[\t ]*include[\t \"\']+#{load_config_file}[\r\n\t \"\']*$/)
					if include_found
						break
					end
				end

				if !include_found
					File.open(gitolite_path, "w") do |file|
						file.puts "include \"#{load_config_file}\""
						file.print gitolite_conf_lines.join("") 
					end
				end
			end
		end


		private
		def load_repos
			@original_content = []
			@repositories = ActiveSupport::OrderedHash.new
			cur_repo_name = nil
			File.new(@path, "w") unless File.exists?(@path)
			File.open(@path).each_line do |line|
				@original_content << line
				tokens = line.strip.split
				if tokens.first == 'repo'
					cur_repo_name = tokens.last
					@repositories[cur_repo_name] = GitoliteAccessRights.new
					next
				end
				cur_repo_right = @repositories[cur_repo_name]
				if cur_repo_right and tokens[1] == '='
					cur_repo_right.add tokens.first, tokens[2..-1]
				end
			end
			@original_content = @original_content.join
		end

		def get_admin_user_key
			admin_user_key = nil
			begin
				admin_user_key = @repositories["gitolite-admin"].rights["RW+".to_sym][0]
			rescue
				admin_user_key = nil
			end
			if admin_user_key == nil
				dir_path = @path
				dir_path = file_path.gsub(/[^\/]*$/,"")
				glob_files = Dir.glob("#{dir_path}/*").reject { |fileName| fileName.match(/gitolite\.conf$/) }
				glob_files.unshift("#{dir_path}/gitolite.conf")
				admin_user_key = ""
				for file_path in @files
					file = File.new(file_path, "r")
					while (line = file.gets)
						if(line.match(/^repo[\t ]+gitolite\-admin[\t ]*$/))
							if(line = file.gets)
								if(line.match(/^[\t ]*RW\+[\t ]*=[\t ]*/))
									user_keys=line.gsub(/^[\t ]*RW\+[\t ]*=[\t ]*/, "").split(/[\t ]+/)
									admin_user_key = user_keys[0]
								end
							end
						end
					end
					file.close
					if admin_user_key != ""
						break;
					end
				end
			end
			admin_user_key
		end




		def repository repo_name
			@repositories[repo_name] ||= GitoliteAccessRights.new
		end




		def content
			content = []

			# To facilitate creation of repos, even when no users are defined
			# always define at least one user -- specifically the admin
			# user which has rights to modify gitolite-admin and control
			# all repos.  Since the gitolite-admin user can grant anyone
			# any permission anyway, this isn't really a security risk.
			# If no users are defined, this ensures the repo actually
			# gets created, hence it's necessary.
			@repositories.each do |repo, rights|
				content << "repo\t#{repo}"
				has_users=false
				rights.each do |perm, users|
					if users.length > 0
						has_users=true
						content << "\t#{perm}\t=\t#{users.join(' ')}"
					end
				end
				if !has_users
					content << "\tR\t=\t#{@admin_user_key}"
				end
				content << ""
			end
			return content.join("\n")
		end

	end

	class GitoliteAccessRights
		def initialize
			@rights = ActiveSupport::OrderedHash.new
		end

		def rights
			@rights
		end

		def add perm, users
			@rights[perm.to_sym] ||= []
			@rights[perm.to_sym] << users
			@rights[perm.to_sym].flatten!
			@rights[perm.to_sym].uniq!
		end

		def set perm, users
			@rights[perm.to_sym] = []
			add perm, users
		end

		def each
			@rights.each {|k,v| yield k, v}
		end
	end
end

