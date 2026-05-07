require "rails_helper"

RSpec.describe "POST /webhooks/vapi", type: :request do
  let(:secret) { "test-webhook-secret" }
  let(:call_plan) { create(:call_plan, :approved) }
  let(:call_session) { create(:call_session, call_plan: call_plan, status: "dialing", vapi_call_id: "vapi-abc") }

  def sign(body, key = secret)
    OpenSSL::HMAC.hexdigest("SHA256", key, body)
  end

  def post_event(payload, sig: nil)
    body = payload.to_json
    headers = {"Content-Type" => "application/json"}
    headers["x-vapi-signature"] = sig || sign(body) if sig != :none
    post "/webhooks/vapi", params: body, headers: headers
  end

  before do
    allow(Rails.application.credentials).to receive(:vapi_webhook_secret).and_return(secret)
    call_session # ensure it exists
  end

  it "returns 200 for valid signature" do
    post_event({"type" => "call.connected", "call" => {"id" => call_session.vapi_call_id}})
    expect(response).to have_http_status(:ok)
  end

  it "returns 401 for invalid signature" do
    post_event({"type" => "call.connected", "call" => {"id" => call_session.vapi_call_id}}, sig: "badsig")
    expect(response).to have_http_status(:unauthorized)
  end

  it "returns 400 for malformed JSON" do
    post "/webhooks/vapi",
      params: "not-json{{{",
      headers: {"Content-Type" => "application/json", "x-vapi-signature" => sign("not-json{{{")}
    expect(response).to have_http_status(:bad_request)
  end

  it "processes call.connected event" do
    post_event({"type" => "call.connected", "call" => {"id" => call_session.vapi_call_id}})
    expect(call_session.reload.status).to eq("connected")
  end

  it "processes call.ended and completes from connected" do
    call_session.update!(status: "connected")
    post_event({"type" => "call.ended", "call" => {"id" => call_session.vapi_call_id}})
    expect(call_session.reload.status).to eq("completed")
  end

  it "processes call.ended and sets voicemail" do
    call_session.update!(status: "connected")
    post_event({"type" => "call.ended", "call" => {"id" => call_session.vapi_call_id, "endedReason" => "voicemail"}})
    expect(call_session.reload.status).to eq("voicemail")
  end

  it "handles unknown events gracefully" do
    post_event({"type" => "some.future.event", "call" => {"id" => call_session.vapi_call_id}})
    expect(response).to have_http_status(:ok)
  end

  it "is idempotent for duplicate events" do
    call_session.update!(status: "connected")
    post_event({"type" => "call.connected", "call" => {"id" => call_session.vapi_call_id}})
    post_event({"type" => "call.connected", "call" => {"id" => call_session.vapi_call_id}})
    expect(call_session.reload.status).to eq("connected")
  end
end
