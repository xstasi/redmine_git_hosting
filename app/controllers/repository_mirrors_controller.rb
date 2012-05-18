class RepositoryMirrorsController < ApplicationController
	unloadable

	before_filter :require_login
	before_filter :set_user_variable
	before_filter :set_project_variable
	before_filter :check_required_permissions
	before_filter :check_xhr_request
	before_filter :find_repository_mirror, :except => [:index, :create]

	menu_item :settings, :only => :settings

	layout Proc.new { |controller| controller.request.xhr? ? 'popup' : 'base' }

	def index
		render_404
	end

	def create
		@mirror = RepositoryMirror.new(params[:repository_mirrors])
		if request.get?
			# display create view
		else
			@mirror.update_attributes(params[:repository_mirrors])
			@mirror.project = @project

			if @mirror.save
				respond_to do |format|
					format.html {
						redirect_to(
							url_for(
								:controller => 'projects',
								:action => 'settings',
								:id => @mirror.project.identifier,
								:tab => 'repository'
							),
							:notice => l(:mirror_notice_created)
						)
					}
				end
			else
				respond_to do |format|
					flash[:notice] = l(:mirror_notice_create_failed)
				end
			end
		end
	end

	def edit
	end

	def update
		respond_to do |format|
			if @mirror.update_attributes(params[:repository_mirrors])
				format.html {
					redirect_to(
						url_for(
							:controller => 'projects',
							:action => 'settings',
							:id => @mirror.project.identifier,
							:tab => 'repository'
						),
						:notice => l(:mirror_notice_updated)
					)
				}
			else
				format.html { render :action => "edit" }
			end
		end


	end

	def destroy
		if request.get?
			# display confirmation view
		else
			if params[:confirm]
				redirect_url = url_for(
					:controller => 'projects',
					:action => 'settings',
					:id => @mirror.project.identifier,
					:tab => 'repository'
				)
				@mirror.destroy
				respond_to do |format|
					format.html {redirect_to(redirect_url, :notice => l(:mirror_notice_deleted))}
				end
			end
		end
	end

	def settings
	end

	def push
		respond_to do |format|
			format.html {
				(@push_failed,@shellout) = @mirror.push
			}
		end
	end

	protected



	def set_user_variable
		@user = User.current
	end

	def set_project_variable
		@project = Project.find(:first, :conditions => ["identifier = ?", params[:project_id]])
	end

	def find_repository_mirror
		mirror = RepositoryMirror.find_by_id(params[:id])

		@mirrors = @project.repository_mirrors

		if mirror and mirror.project == @project
			@mirror = mirror
		elsif mirror
			render_403
		else
			render_404
		end
	end

	def check_required_permissions
		# Deny access if the curreent user is not allowed to manage the project's repositoy
		if not @project.module_enabled?(:repository)
			render_403
		end
		not_enough_perms = true
		@user.roles_for_project(@project).each{|role|
			if role.allowed_to? :manage_repository
				not_enough_perms = false
				break
			end
		}
		if not_enough_perms
			render_403
		end
	end

	def check_xhr_request
		@is_xhr ||= request.xhr?
	end

end
