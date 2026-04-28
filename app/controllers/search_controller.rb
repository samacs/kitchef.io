class SearchController < AuthenticatedController
  def show
    @term = params[:q].to_s.strip
    @result = Search::Omnisearch.call(
      account: Current.account,
      term: @term,
      limit_per_group: 5
    )
  end
end
