class SearchController < AuthenticatedController
  def show
    @term = params[:q].to_s.strip
    @result = Search::Omnisearch.call(
      account: Current.account,
      term: @term,
      limit_per_group: 5
    )

    if params[:palette].present?
      render partial: "search/palette_results", layout: false
    end
  end
end
