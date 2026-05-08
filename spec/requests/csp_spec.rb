require "rails_helper"

RSpec.describe "Content Security Policy", type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  it "sends a Content-Security-Policy header on HTML responses" do
    get delegations_path
    expect(response.headers["Content-Security-Policy"]).to be_present
  end

  it "includes default-src 'self'" do
    get delegations_path
    expect(response.headers["Content-Security-Policy"]).to include("default-src 'self'")
  end

  it "disallows object-src" do
    get delegations_path
    expect(response.headers["Content-Security-Policy"]).to include("object-src 'none'")
  end

  it "allows Google Fonts in style-src" do
    get delegations_path
    expect(response.headers["Content-Security-Policy"]).to include("fonts.googleapis.com")
  end
end
