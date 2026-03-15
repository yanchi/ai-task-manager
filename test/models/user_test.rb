require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "メールアドレスが必須" do
    user = User.new(password: "password")
    assert_not user.valid?
    assert user.errors[:email].present?
  end

  test "メールアドレスが重複するとNG" do
    existing = users(:alice)
    user = User.new(email: existing.email, password: "password")
    assert_not user.valid?
  end

  test "TLDなしのメールアドレスはNG" do
    user = User.new(email: "test@invalid", password: "password")
    assert_not user.valid?
  end

  test "正常なメールアドレスはOK" do
    user = User.new(email: "new@example.com", password: "password")
    assert user.valid?
  end

  test "タスクとのアソシエーションが機能する" do
    assert_equal 3, users(:alice).tasks.count
    assert_equal 1, users(:bob).tasks.count
  end
end
