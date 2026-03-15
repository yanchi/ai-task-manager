class User < ApplicationRecord
  # Devise モジュール
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # アソシエーション
  has_many :tasks, dependent: :destroy

  # バリデーション
  validates :email, presence: true, uniqueness: true
end
