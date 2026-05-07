require "rails_helper"

RSpec.describe "POST /webhooks/vapi", type: :request do
  let(:secret) { "test-webhook-secret" }
  let(:call_plan) { create(:call_plan, :approved) }
  let(:call_session) { create(:call_session, call_plan: call_plan, status: "dialing", vapi_call_id: "vapi-abc") }

  # Vapi wraps all server messages in a top-level "message" key
  def post_event(message_payload, token: secret)
    body = { "message" => message_payload }.to_json
    headers = { "Content-Type" => "application/json" }
    headers["Authorization"] = "Bearer #{token}" if token
    post "/webhooks/vapi", params: body, headers: headers
  end

  before do
    allow(Rails.application.credentials).to receive(:vapi_webhook_secret).and_return(secret)
    call_session # ensure it exists
  end

  it "returns 200 for valid token" do
    post_event({ "type" => "status-update", "call" => { "id" => call_session.vapi_call_id }, "status" => "ringing" })
    expect(response).to have_http_status(:ok)
  end

  it "returns 401 for invalid token" do
    post_event({ "type" => "status-update", "call" => { "id" => call_session.vapi_call_id }, "status" => "ringing" }, token: "wrongtoken")
    expect(response).to have_http_status(:unauthorized)
  end

  it "returns 400 for malformed JSON" do
    post "/webhooks/vapi",
      params: "not-json{{{",
      headers: { "Content-Type" => "application/json", "Authorization" => "Bearer #{secret}" }
    expect(response).to have_http_status(:bad_request)
  end

  it "processes status-update in-progress → connected" do
    post_event({ "type" => "status-update", "call" => { "id" => call_session.vapi_call_id }, "status" => "in-progress" })
    expect(call_session.reload.status).to eq("connected")
  end

  it "processes end-of-call-report and completes from connected" do
    call_session.update!(status: "connected")
    post_event({ "type" => "end-of-call-report", "call" => { "id" => call_session.vapi_call_id } })
    expect(call_session.reload.status).to eq("completed")
  end

  it "processes end-of-call-report and sets voicemail" do
    call_session.update!(status: "connected")
    post_event({ "type" => "end-of-call-report", "call" => { "id" => call_session.vapi_call_id, "endedReason" => "voicemail" } })
    expect(call_session.reload.status).to eq("voicemail")
  end

  it "handles unknown events gracefully" do
    post_event({ "type" => "some.future.event", "call" => { "id" => call_session.vapi_call_id } })
    expect(response).to have_http_status(:ok)
  end

  it "is idempotent for duplicate status-update events" do
    post_event({ "type" => "status-update", "call" => { "id" => call_session.vapi_call_id }, "status" => "in-progress" })
    post_event({ "type" => "status-update", "call" => { "id" => call_session.vapi_call_id }, "status" => "in-progress" })
    expect(call_session.reload.status).to eq("connected")
  end
end
