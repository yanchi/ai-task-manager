FROM ruby:3.3.0

# Node.js と Yarn のインストール
RUN apt-get update -qq && apt-get install -y \
  nodejs \
  npm \
  postgresql-client \
  && rm -rf /var/lib/apt/lists/*

RUN npm install -g yarn

# 作業ディレクトリの設定
WORKDIR /app

# Gemfile をコピーして bundle install
COPY Gemfile Gemfile.lock ./
RUN bundle install

# エントリポイントスクリプトをコピー
COPY entrypoint.sh /usr/bin/
RUN chmod +x /usr/bin/entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]

# アプリケーションのコードをコピー
COPY . .

# Puma の起動
EXPOSE 3000
CMD ["rails", "server", "-b", "0.0.0.0"]
