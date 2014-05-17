require File.expand_path("helper", File.dirname(__FILE__))

module Nori
  class StringWithAttributes < String
  end

  class Unknown
  end
end

describe Kasket::Visitor do
  it "build select id" do
    expected = {
      :attributes=>[[:id, "1"]],
      :from=>"posts",
      :index=>[:id],
      :key=>"#{Post.kasket_key_prefix}id=1"
    }
    assert_equal expected, Post.where(:id => 1).to_kasket_query
  end

  it "build from Nori::StringWithAttributes" do
    expected = {
      :attributes=>[[:id, "1"]],
      :from=>"posts",
      :index=>[:id],
      :key=>"#{Post.kasket_key_prefix}id=1"
    }
    assert_equal expected, Post.where(:id => Nori::StringWithAttributes.new("1")).to_kasket_query
  end

  it "notify on missing attribute" do
    assert_equal nil, Post.where(:id => Nori::Unknown.new).to_kasket_query
  end
end
