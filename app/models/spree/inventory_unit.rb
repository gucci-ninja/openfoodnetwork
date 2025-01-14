# frozen_string_literal: true

module Spree
  class InventoryUnit < ActiveRecord::Base
    belongs_to :variant, -> { with_deleted }, class_name: "Spree::Variant"
    belongs_to :order, class_name: "Spree::Order"
    belongs_to :shipment, class_name: "Spree::Shipment"
    belongs_to :return_authorization, class_name: "Spree::ReturnAuthorization",
                                      inverse_of: :inventory_units

    scope :backordered, -> { where state: 'backordered' }
    scope :shipped, -> { where state: 'shipped' }
    scope :backordered_per_variant, ->(stock_item) do
      includes(:shipment)
        .where("spree_shipments.state != 'canceled'").references(:shipment)
        .where(variant_id: stock_item.variant_id)
        .backordered.order("#{table_name}.created_at ASC")
    end

    # state machine (see http://github.com/pluginaweek/state_machine/tree/master for details)
    state_machine initial: :on_hand do
      event :fill_backorder do
        transition to: :on_hand, from: :backordered
      end
      after_transition on: :fill_backorder, do: :update_order

      event :ship do
        transition to: :shipped, if: :allow_ship?
      end

      event :return do
        transition to: :returned, from: :shipped
      end
    end

    # This was refactored from a simpler query because the previous implementation
    # lead to issues once users tried to modify the objects returned. That's due
    # to ActiveRecord `joins(shipment: :stock_location)` only return readonly
    # objects
    #
    # Returns an array of backordered inventory units as per a given stock item
    def self.backordered_for_stock_item(stock_item)
      backordered_per_variant(stock_item).select do |unit|
        unit.shipment.stock_location == stock_item.stock_location
      end
    end

    def self.finalize_units!(inventory_units)
      inventory_units.map do |iu|
        iu.update_columns(
          pending: false,
          updated_at: Time.zone.now
        )
      end
    end

    def find_stock_item
      Spree::StockItem.find_by(stock_location_id: shipment.stock_location_id,
                               variant_id: variant_id)
    end

    private

    def allow_ship?
      Spree::Config[:allow_backorder_shipping] || on_hand?
    end

    def update_order
      order.update!
    end
  end
end
