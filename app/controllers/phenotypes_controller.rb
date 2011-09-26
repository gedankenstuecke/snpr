class PhenotypesController < ApplicationController
    before_filter :require_user, only: [ :new, :create, :get_genotypes ]
	  helper_method :sort_column, :sort_direction
	
	def index
	  @phenotypes = Phenotype.order(sort_column + " " + sort_direction)
	  @phenotypes_paginate = @phenotypes.paginate(:page => params[:page],:per_page => 10)
    respond_to do |format|
			format.html
			format.xml 
		end
  end
  
	def new
		@phenotype = Phenotype.new
		@user_phenotype = UserPhenotype.new
		@title = "Create a new phenotype"

		respond_to do |format|
			format.html
			format.xml
		end
	end

	def create
	  unless Phenotype.find_by_characteristic(params[:phenotype][:characteristic])
		  @phenotype = Phenotype.create(params[:phenotype])

			# award: created one (or more) phenotypes
	    current_user.update_attributes(:phenotype_creation_counter => (current_user.phenotype_creation_counter + 1)  )

		  check_and_award_new_phenotypes(1, "Created a new phenotype")
		  check_and_award_new_phenotypes(5, "Created 5 new phenotypes")
		  check_and_award_new_phenotypes(10, "Created 10 new phenotypes")

	  else
	    @phenotype = Phenotype.find_by_characteristic(params[:phenotype][:characteristic])
		end

		unless @phenotype.known_phenotypes.include?(params[:user_phenotype][:variation])
		  @phenotype.known_phenotypes << params[:user_phenotype][:variation]
	  end
	  
	  @phenotype.save
	  @phenotype = Phenotype.find_by_characteristic(params[:phenotype][:characteristic])
    
		@user_phenotype = UserPhenotype.new(:user_id => current_user.id, :phenotype_id => @phenotype.id, :variation => params[:user_phenotype][:variation])
	
		if @user_phenotype.save
		  @phenotype.number_of_users = UserPhenotype.find_all_by_phenotype_id(@phenotype.id).length 
      @phenotype.save
			
			# check for additional phenotype awards
	    current_user.update_attributes(:phenotype_additional_counter => (current_user.user_phenotypes.length))

			check_and_award_additional_phenotypes(5, "Entered 5 additional phenotypes")
			check_and_award_additional_phenotypes(10, "Entered 10 additional phenotypes")
			check_and_award_additional_phenotypes(20, "Entered 20 additional phenotypes")
			check_and_award_additional_phenotypes(50, "Entered 50 additional phenotypes")
			check_and_award_additional_phenotypes(100, "Entered 100 additional phenotypes")

			redirect_to current_user
		else
			redirect_to :action => "new", :notice => "Something went wrong in creating the phenotype"
		end
	end
  
	def show
		#@phenotypes = Phenotype.where(:user_id => current_user.id).all
		#@title = "Phenotypes"
		@phenotype = Phenotype.find(params[:id])
		@comments = PhenotypeComment.where(:phenotype_id => params[:id]).all(:order => "created_at ASC")
		@phenotype_comment = PhenotypeComment.new
		@user_phenotype = UserPhenotype.new
		
		respond_to do |format|
			format.html
			format.xml
		end
	end

=begin
	def edit
		@title = "Edit your Phenotypes"
		@phenotypes = Phenotype.where(:user_id => current_user.id).all
		respond_to do |format|
			format.html
			format.xml
		end
	end
=end
	
	def feed
    @phenotype = Phenotype.find(params[:id])
    @user_phenotypes = @phenotype.user_phenotypes
    @genotypes = []
    @user_phenotypes.each do |up|
      if up.user.genotypes[0] != nil
        @genotypes << up.user.genotypes[0]
      end
    end
    
    @genotypes.sort!{ |b,a| a.created_at <=> b.created_at }
    
    render :action => "rss", :layout => false
  end
  
  def get_genotypes
    Resque.enqueue(Zipgenotypingfiles, params[:id],
                   params[:variation], current_user.email)
    @phenotype = Phenotype.find(params[:id])
    @variation = params[:variation]
    respond_to do |format|
			format.html
			format.xml
		end
  end
	
	  private
	  
		def sort_column
			Phenotype.column_names.include?(params[:sort]) ? params[:sort] : "number_of_users"
	  end
	  
	  def sort_direction
		%w[desc asc].include?(params[:direction]) ? params[:direction] : "desc"
	  end

		def check_and_award_new_phenotypes(amount, achievement_string)
			if current_user.phenotype_creation_counter == amount # 10
				UserAchievement.create(:achievement_id => Achievement.find_by_award(achievement_string).id, :user_id => current_user.id)
			end
		end

		def check_and_award_additional_phenotypes(amount, achievement_string)
			if current_user.phenotype_additional_counter == amount #100
         UserAchievement.create(:user_id => current_user.id, :achievement_id => Achievement.find_by_award(achievement_string))
			end
		end
end
