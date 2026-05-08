require "rails_helper"

RSpec.describe EscalationNotifier, type: :service do
  let(:user) { create(:user) }
  let(:delegation) { create(:delegation, user: user) }
  let(:call_plan) { create(:call_plan, :approved, delegation: delegation) }
  let(:session) { create(:call_session, call_plan: call_plan, status: "needs_user") }
  let(:escalation) { create(:escalation, call_session: session) }

  describe ".notify" do
    context "user has enabled channels" do
      let!(:pushover_channel) { create(:notification_channel, :pushover, user: user) }
      let!(:telegram_channel) { create(:notification_channel, :telegram, user: user) }

      it "dispatches to all enabled channels" do
        pushover_double = instance_double(Notifiers::PushoverChannel, deliver: nil)
        telegram_double = instance_double(Notifiers::TelegramChannel, deliver: nil)

        allow(Notifiers::PushoverChannel).to receive(:new).with(pushover_channel).and_return(pushover_double)
        allow(Notifiers::TelegramChannel).to receive(:new).with(telegram_channel).and_return(telegram_double)

        described_class.notify(escalation: escalation, user: user)

        expect(pushover_double).to have_received(:deliver).with(escalation: escalation)
        expect(telegram_double).to have_received(:deliver).with(escalation: escalation)
      end

      it "sets notified_at after dispatch" do
        allow_any_instance_of(Notifiers::PushoverChannel).to receive(:deliver)
        allow_any_instance_of(Notifiers::TelegramChannel).to receive(:deliver)

        described_class.notify(escalation: escalation, user: user)

        expect(escalation.reload.notified_at).to be_present
      end

      it "skips disabled channels" do
        pushover_channel.update!(enabled: false)
        telegram_double = instance_double(Notifiers::TelegramChannel, deliver: nil)
        allow(Notifiers::TelegramChannel).to receive(:new).and_return(telegram_double)

        expect(Notifiers::PushoverChannel).not_to receive(:new)

        described_class.notify(escalation: escalation, user: user)
        expect(telegram_double).to have_received(:deliver)
      end
    end

    context "user has no enabled channels" do
      it "logs error and still sets notified_at" do
        expect(Rails.logger).to receive(:error).with(/no enabled notification channels/i)
        described_class.notify(escalation: escalation, user: user)
        expect(escalation.reload.notified_at).to be_present
      end

      it "does not raise" do
        allow(Rails.logger).to receive(:error)
        expect { described_class.notify(escalation: escalation, user: user) }.not_to raise_error
      end
    end

    context "a channel raises an error" do
      let!(:pushover_channel) { create(:notification_channel, :pushover, user: user) }

      it "logs the error and still sets notified_at" do
        allow_any_instance_of(Notifiers::PushoverChannel).to receive(:deliver).and_raise(StandardError, "network error")
        expect(Rails.logger).to receive(:error).with(/network error/)
        expect { described_class.notify(escalation: escalation, user: user) }.not_to raise_error
        expect(escalation.reload.notified_at).to be_present
      end
    end
  end
end
