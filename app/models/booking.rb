class Booking < ActiveRecord::Base
  attr_accessible :user_id, :space_id, :start_date, :end_date,
                  :approval_status, :total, :service_fee,
                  :booking_rate_daily, :guest_count

  validates_presence_of :user_id, :space_id, :start_date, :end_date,
                        :approval_status, :total, :service_fee,
                        :booking_rate_daily, :guest_count

  belongs_to :user
  belongs_to :space

  def self.approval_statuses
    {canceled_by_user: -4,
    canceled_by_owner: -3,
              timeout: -2,
             declined: -1,
             unbooked:  0,
              pending:  1,
             approved:  2,
                  -4 => "canceled_by_user",
                  -3 => "canceled_by_owner",
                  -2 => "timeout",
                  -1 => "declined",
                   0 => "unbooked",
                   1 => "pending",
                   2 => "approved"}
  end

  def self.find_booking_and_update_approval_status(booking_id, method)
    booking = Booking.find_by_id(booking_id)
    booking.public_send(method)
  end

  def set_approval_status(status)
    self.update_attributes!(approval_status: status)
  end

  def overlapping_requests(status)
    CatRentalRequest
    .where("space_id = ?"   , self.space_id)
    .where("? <= end_date"  , self.start_date)
    .where("? >= start_date", self.end_date)
    .where("id != ?"        , self.id)
    .where("status = ?"     , Booking.approval_statuses(status))
  end

  def decline_conflicting_pending_requests!
    overlapping_pending_requests.each { |request| request.decline }
  end

  def cancel_by_user
    self.set_approval_status(Booking.approval_statuses[:canceled_by_user])
  end

  def cancel_by_owner
    self.set_approval_status(Booking.approval_statuses[:canceled_by_owner])
  end

  def decline
    self.set_approval_status(Booking.approval_statuses[:declined])
  end

  def book
    unless overlapping_requests(:approved)
      self.set_approval_status(Booking.approval_statuses[:pending])
    end
  end

  def approve
    self.set_approval_status(Booking.approval_statuses[:approved])
    self.decline_conflicting_pending_requests!
  end

end
