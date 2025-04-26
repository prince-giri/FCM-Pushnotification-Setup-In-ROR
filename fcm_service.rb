module Notifications
  class FcmService
    require 'googleauth'
    require 'json'
    require 'stringio'
    require 'faraday'
    FCM_URL = 'https://fcm.googleapis.com/v1/projects/renotary-app/messages:send'.freeze

    def initialize
      @token = fetch_access_token
    end

    def send_notification(device_id, body)
      message_content = process_html_tags(body)

      payload = {
        "message": {
          "token": "#{device_id}",
          "notification": {
            "title": "Renotary Notification",
            "body": "#{message_content}"
          },
          "android": {
            "priority": "high",
            "notification": {
              "channel_id": "default",
              "sound": "default"
            }
          },
          "apns": {
            "headers": {
              "apns-priority": "10"
            }
          }
        }
      }
      response = Faraday.post(FCM_URL, payload.to_json, headers)

      if response.success?
        puts "Push Notification sent successfully"
      else
        puts "Failed to send push notification: #{response.status} - #{response.body}"
      end
    end

    private

    def process_html_tags(content)
      doc = Nokogiri::HTML::DocumentFragment.parse(content)
      doc.css('p').each { |p| p.replace("\n#{p.text}\n") }
      doc.css('b').each { |b| b.replace("**#{b.text}**") }

      doc.css('*').each do |node|
        node.replace(node.text) unless node.name == 'p' || node.name == 'b'
      end
      doc.text.strip
    end

    def fetch_access_token
      private_key = ENV['FCM_PRIVATE_KEY']
      private_key_hash = {
        type: "service_account",
        project_id: "renotary-app",
        private_key_id: "526a08f647168fc5f1c36826877d69c56daa0670",
        private_key: private_key,
        client_email: "firebase-adminsdk-11mnr@renotary-app.iam.gserviceaccount.com",
        client_id: "108627455275925739749",
        auth_uri: "https://accounts.google.com/o/oauth2/auth",
        token_uri: "https://oauth2.googleapis.com/token",
        auth_provider_x509_cert_url: "https://www.googleapis.com/oauth2/v1/certs",
        client_x509_cert_url: "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-11mnr%40renotary-app.iam.gserviceaccount.com",
        universe_domain: "googleapis.com"
      }

      unless Rails.env.test?
        private_key_json = private_key_hash.to_json
        credentials = Google::Auth::ServiceAccountCredentials.make_creds(
          json_key_io: StringIO.new(private_key_json),
          scope: 'https://www.googleapis.com/auth/firebase.messaging'
        )
        credentials.fetch_access_token!['access_token']
      end
    end

    def headers
      {
        'Authorization' => "Bearer #{@token}",
        'Content-Type' => 'application/json'
      }
    end
  end
end
