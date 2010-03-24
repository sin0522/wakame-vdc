require 'sequel'

module Dcmgr
  module Models
    class AccountLog < Sequel::Model
      many_to_one :account
      many_to_one :user, :left_primary_key=>:user_id

      def before_create
        super
        self.created_at = Time.now unless self.created_at
      end

      def validate
        errors.add(:account, "can't empty") unless (self.account or self.account_id)
        errors.add(:tareget_uuid, "can't empty") unless self.target_uuid
        errors.add(:target_type, "can't empty") unless self.target_type
        errors.add(:usage_value, "can't empty") unless self.usage_value
      end

      def self.last_date(year, month)
        next_year = month == 12? year + 1: year
        next_month = month == 12? 1: month + 1
        t = Time.local(next_year, next_month, 1)
        if t > (now = Time.now)
          now
        else
          t
        end
      end

      def self.generate(year, month)
        target_date = Time.local(year, month)
        
        clear(year, month)

        current_month_instances(year, month).merge(preview_month_instances(year, month)).each_value{|instance|
          logs = instance_logs(year, month, instance.target_uuid).map{|i|
            {:action=>i.action, :date=>i.created_at}
          }

          usage_sec = 0.0
          start = if instance.created_at < target_date
                    target_date
                  else
                    nil
                  end

          puts "instance:"
          p instance
          puts "start:"
          p start
          puts "logs:"
          p logs
          puts ""

          logs.each{|lg|
            if lg[:action] == "run"
              start = lg[:date]
            elsif lg[:action] == "terminate"
              usage_sec += lg[:date] - start
            end
          }

          if logs and logs.last and logs.last[:action] == "run"
            usage_sec += last_date(year, month) - logs.last[:date]
          end
          
          if instance.created_at < target_date
            if not logs or logs.length == 0
              usage_sec += last_date(year, month) - target_date # one month
            end
          end

          create(:target_date=>Time.local(year, month),
                 :account_id=>instance.account_id,
                 :target_uuid=>instance.target_uuid,
                 :target_type=>TagMapping::TYPE_INSTANCE,
                 :usage_value=>(usage_sec / 60).ceil)
        }
      end

      def self.preview_month_instances(year, month)
        ret = Hash.new
        dt = Time.local(year, month)
        Log.filter{created_at < dt}.filter{:target_uuid.like('I-%')}.
          group(:target_uuid).all.each{|instance|
          latest_instance = Log.filter(:target_uuid=>instance.target_uuid).filter{created_at < dt}.order(:created_at.desc).first
          if latest_instance.action == "run"
            ret[instance.target_uuid] = instance
          end
        }
        ret
      end

      def self.current_month_instances(year, month)
        ret = Hash.new
        Log.filter("YEAR(created_at) = ? AND MONTH(created_at) = ?" +
                   " AND target_uuid LIKE 'I-%'",
                   year, month).group(:target_uuid).all.each{|l|
          ret[l.target_uuid] = l
        }
        ret
      end

      def self.instance_logs(year, month, uuid)
        Log.filter("YEAR(created_at) = ? AND MONTH(created_at) = ?" +
                   " AND target_uuid = ?",
                   year, month, uuid).order(:target_uuid).all
      end

      def self.clear(year, month)
        filter('YEAR(target_date) = ? AND MONTH(target_date) = ?',
               year, month).delete
      end
    end
  end
end
