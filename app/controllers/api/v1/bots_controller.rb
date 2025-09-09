class Api::V1::BotsController < Api::V1::BaseController
  before_action :find_bot, only: [:show, :update, :destroy, :status, :activate, :deactivate]
  
  def index
    bots = Bot.all.order(:name)
    render json: {
      bots: bots.map do |bot|
        {
          id: bot.id,
          name: bot.name,
          description: bot.description,
          active: bot.active,
          bot_type: bot.bot_type,
          webhook_id: bot.webhook_id,
          created_at: bot.created_at.iso8601
        }
      end
    }
  end
  
  def show
    render json: {
      bot: {
        id: @bot.id,
        name: @bot.name,
        description: @bot.description,
        active: @bot.active,
        bot_type: @bot.bot_type,
        webhook_id: @bot.webhook_id,
        created_at: @bot.created_at.iso8601,
        updated_at: @bot.updated_at.iso8601
      }
    }
  end
  
  def create
    bot = Bot.new(bot_params)
    bot.webhook_id = params[:webhook_id] if params[:webhook_id].present?
    bot.bot_type = params[:type] || 'webhook'
    bot.active = true
    
    if bot.save
      render_success({
        bot: {
          id: bot.id,
          name: bot.name,
          description: bot.description,
          active: bot.active,
          bot_type: bot.bot_type,
          webhook_id: bot.webhook_id
        }
      }, 'Bot created successfully')
    else
      render_error("Failed to create bot: #{bot.errors.full_messages.join(', ')}")
    end
  end
  
  def update
    if @bot.update(bot_params)
      render_success({
        bot: {
          id: @bot.id,
          name: @bot.name,
          description: @bot.description,
          active: @bot.active,
          bot_type: @bot.bot_type,
          webhook_id: @bot.webhook_id
        }
      }, 'Bot updated successfully')
    else
      render_error("Failed to update bot: #{@bot.errors.full_messages.join(', ')}")
    end
  end
  
  def destroy
    @bot.destroy
    render_success({}, 'Bot deleted successfully')
  end
  
  def status
    render json: {
      bot_id: @bot.id,
      name: @bot.name,
      active: @bot.active,
      last_activity: @bot.updated_at.iso8601,
      message_count: @bot.messages.count,
      status: @bot.active? ? 'active' : 'inactive'
    }
  end
  
  def activate
    @bot.update(active: true)
    render_success({}, 'Bot activated')
  end
  
  def deactivate
    @bot.update(active: false)
    render_success({}, 'Bot deactivated')
  end
  
  private
  
  def find_bot
    @bot = Bot.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_error('Bot not found', :not_found)
  end
  
  def bot_params
    params.permit(:name, :description, :active)
  end
end