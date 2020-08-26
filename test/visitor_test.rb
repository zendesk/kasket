# frozen_string_literal: true
require_relative "helper"

module Nori
  class StringWithAttributes < String
  end

  class Unknown
  end
end

describe Kasket::Visitor do
  it "build select id" do
    expected = {
      attributes: [[:id, "1"]],
      from: "posts",
      index: [:id],
      key: "#{Post.kasket_key_prefix}id=1"
    }

    assert_equal expected, Post.where(id: 1).to_kasket_query
  end

  it "builds select Bignum" do
    num = 9223372036854775807
    assert_equal Post.where(big_id: num).to_kasket_query.fetch(:attributes), [[:big_id, num.to_s]]
  end

  it "builds with nil values" do
    expected = {
      attributes: [[:deleted_at, nil], [:id, "1"]],
      from: "posts",
      index: [:deleted_at, :id],
      key: "#{Post.kasket_key_prefix}deleted_at=/id=1"
    }

    assert_equal expected, Post.where(id: 1, deleted_at: nil).to_kasket_query
  end

  it "build from Nori::StringWithAttributes" do
    expected = {
      attributes: [[:id, "1"]],
      from: "posts",
      index: [:id],
      key: "#{Post.kasket_key_prefix}id=1"
    }
    assert_equal expected, Post.where(id: Nori::StringWithAttributes.new("1")).to_kasket_query
  end

  it "builds consistent keys with boolean values" do
    expected = {
      attributes: [[:public, 1]],
      from: "comments",
      index: [:public],
      key: "#{DefaultComment.kasket_key_prefix}public=#{ActiveRecord::VERSION::STRING < '5.2' ? "1" : "true"}"
    }
    assert_equal expected, DefaultComment.unscoped.where(public: true).to_kasket_query

    expected = {
      attributes: [[:public, 0]],
      from: "comments",
      index: [:public],
      key: "#{DefaultComment.kasket_key_prefix}public=#{ActiveRecord::VERSION::STRING < '5.2' ? "0" : "false"}"
    }
    assert_equal expected, DefaultComment.unscoped.where(public: false).to_kasket_query
  end

  it "notify on missing attribute" do
    assert_nil Post.where(id: Nori::Unknown.new).to_kasket_query
  end
end
