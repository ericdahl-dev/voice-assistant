require "rails_helper"

RSpec.describe Delegation, type: :model do
  it { is_expected.to belong_to(:user) }
  it { is_expected.to belong_to(:call_template).optional }
  it { is_expected.to have_one(:call_plan).dependent(:destroy) }

  it "is valid with a user" do
    expect(build(:delegation)).to be_valid
  end

  it "is invalid without a user" do
    expect(build(:delegation, user: nil)).not_to be_valid
  end
end
