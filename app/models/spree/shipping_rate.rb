# frozen_string_literal: true

module Spree
  class ShippingRate < ActiveRecord::Base
    belongs_to :shipment, class_name: 'Spree::Shipment'
    belongs_to :shipping_method, class_name: 'Spree::ShippingMethod', inverse_of: :shipping_rates

    scope :frontend,
          -> {
            includes(:shipping_method).
              where(ShippingMethod.on_frontend_query).
              references(:shipping_method).
              order("cost ASC")
          }
    scope :backend,
          -> {
            includes(:shipping_method).
              where(ShippingMethod.on_backend_query).
              references(:shipping_method).
              order("cost ASC")
          }

    delegate :order, :currency, to: :shipment
    delegate :name, to: :shipping_method

    def display_price
      price = if Spree::Config[:shipment_inc_vat]
                (1 + Spree::TaxRate.default) * cost
              else
                cost
              end

      Spree::Money.new(price, { currency: currency })
    end

    alias_method :display_cost, :display_price
  end
end
