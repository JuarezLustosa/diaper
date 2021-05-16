# Provides Read-only access to Requests, which are created via an API. Requests are transformed into Distributions.
class RequestsController < ApplicationController
  def index
    setup_date_range_picker

    @requests = current_organization
                .ordered_requests
                .undiscarded
                .during(helpers.selected_range)
                .class_filter(filter_params)

    @paginated_requests = @requests.page(params[:page])
    @calculate_product_totals = RequestsTotalItemsService.new(requests: @requests).calculate
    @items = current_organization.items.alphabetized
    @partners = current_organization.partners.order(:name)
    @statuses = Request.statuses.transform_keys(&:humanize)
    @selected_request_item = filter_params[:by_request_item_id]
    @selected_partner = filter_params[:by_partner]
    @selected_status = filter_params[:by_status]

    respond_to do |format|
      format.html
      format.csv { send_data Request.generate_csv(@requests), filename: "Requests-#{Time.zone.today}.csv" }
    end
  end

  def show
    @request = Request.find(params[:id])
    @request_items = load_items
  end

  # Clicking the "New Distribution" button will set the the request to started
  # and will move the user to the new distribution page with a
  # pre-filled distribution containing all the requested items.
  def start
    request = Request.find(params[:id])
    request.status_started!
    flash[:notice] = "Request started"
    redirect_to new_distribution_path(request_id: request.id)
  end

  def destroy
    svc = RequestDestroyService.new(request_id: params[:id])
    svc.call

    if svc.errors.none?
      flash[:notice] = "Request #{params[:id]} has been removed!"
    else
      errors = svc.errors.full_messages.join(", ")
      flash[:notice] = "Request #{params[:id]} could not be removed because #{errors}"
    end

    redirect_to requests_path
  end

  private

  def load_items
    return unless @request.request_items

    @request.request_items.map { |json| RequestItem.from_json(json, current_organization) }
  end

  helper_method \
    def filter_params
    return {} unless params.key?(:filters)

    params.require(:filters).permit(:by_request_item_id, :by_partner, :by_status)
  end
end
