#!/bin/bash

# enhanced-setup-server.sh - Cài đặt hệ thống auto-deploy nâng cao cho tên miền tùy chọn
# Sử dụng: bash enhanced-setup-server.sh [--domain tenmien.com]

# Đảm bảo script chạy với quyền root
if [[ $EUID -ne 0 ]]; then
   echo "Script này phải được chạy với quyền root" 
   exit 1
fi

# Thiết lập màu sắc cho output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] CẢNH BÁO: $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] LỖI: $1${NC}"
}

# Hiển thị cách sử dụng
show_usage() {
    echo "Sử dụng: $0 [--domain tenmien.com]"
    echo ""
    echo "Options:"
    echo "  --domain <domain>    Tên miền chính được sử dụng để tạo các subdomain (mặc định: nodejs.io.vn)"
    echo ""
    echo "Chú ý: Bạn cần trỏ DNS wildcard (*.tenmien.com) đến IP của VPS này trước khi chạy script!"
    exit 1
}

# Thiết lập domain chính mặc định
MAIN_DOMAIN="nodejs.io.vn"

# Xử lý tham số
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --domain)
            MAIN_DOMAIN="$2"
            if [[ ! $MAIN_DOMAIN =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
                error "Tên miền không hợp lệ: $MAIN_DOMAIN"
                show_usage
            fi
            shift 2
            ;;
        --help)
            show_usage
            ;;
        *)
            error "Tham số không được hỗ trợ: $1"
            show_usage
            ;;
    esac
done

# Lấy IP của máy chủ
SERVER_IP=$(hostname -I | awk '{print $1}')

# Hiển thị thông báo quan trọng về cấu hình DNS
echo -e "\n${YELLOW}============= THÔNG BÁO QUAN TRỌNG ==============${NC}"
echo -e "${YELLOW}Trước khi tiếp tục, vui lòng đảm bảo bạn đã cấu hình DNS như sau:${NC}"
echo -e "1. Trỏ bản ghi A cho ${YELLOW}$MAIN_DOMAIN${NC} đến ${YELLOW}$SERVER_IP${NC}"
echo -e "2. Trỏ bản ghi A cho ${YELLOW}*.$MAIN_DOMAIN${NC} (wildcard) đến ${YELLOW}$SERVER_IP${NC}"
echo -e "\nVí dụ cấu hình DNS:"
echo -e "   ${GREEN}$MAIN_DOMAIN     A     $SERVER_IP${NC}"
echo -e "   ${GREEN}*.$MAIN_DOMAIN   A     $SERVER_IP${NC}"
echo -e "${YELLOW}==============================================${NC}\n"

read -p "Bạn đã cấu hình DNS wildcard chưa? (y/n): " dns_configured
if [[ "$dns_configured" != "y" && "$dns_configured" != "Y" ]]; then
    error "Bạn cần cấu hình DNS wildcard trước khi tiếp tục"
    echo "Vui lòng cấu hình DNS và chạy lại script này"
    exit 1
fi

# Thiết lập thư mục gốc
AUTODEPLOY_ROOT="/opt/autodeploy"

# Tạo cấu trúc thư mục
log "Tạo cấu trúc thư mục..."
mkdir -p $AUTODEPLOY_ROOT/{config/sites,scripts,repos,www,logs/{deploy,nginx,postgres,email}}

# Kiểm tra hệ điều hành
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
else
    OS=$(uname -s)
fi

log "Phát hiện hệ điều hành: $OS"

# Cài đặt các gói phụ thuộc dựa theo hệ điều hành
log "Cài đặt các gói phụ thuộc..."

# Kiểm tra khả năng sử dụng các dịch vụ chính
check_services_availability() {
    log "Kiểm tra các dịch vụ cần thiết..."
    
    # Kiểm tra Node.js
    if ! command -v node &> /dev/null; then
        error "Node.js không được cài đặt hoặc không khả dụng trong PATH"
        return 1
    else
        NODE_VERSION=$(node -v)
        log "Node.js: $NODE_VERSION"
    fi
    
    # Kiểm tra Nginx
    if ! command -v nginx &> /dev/null; then
        error "Nginx không được cài đặt hoặc không khả dụng trong PATH"
        return 1
    else
        NGINX_VERSION=$(nginx -v 2>&1 | cut -d'/' -f2)
        log "Nginx: $NGINX_VERSION"
    fi
    
    # Kiểm tra PostgreSQL
    if ! command -v psql &> /dev/null; then
        error "PostgreSQL không được cài đặt hoặc không khả dụng trong PATH"
        return 1
    else
        PG_VERSION=$(psql --version | awk '{print $3}')
        log "PostgreSQL: $PG_VERSION"
    fi
    
    # Kiểm tra PM2
    if ! command -v pm2 &> /dev/null; then
        error "PM2 không được cài đặt hoặc không khả dụng trong PATH"
        return 1
    else
        PM2_VERSION=$(pm2 -v)
        log "PM2: $PM2_VERSION"
    fi
    
    # Kiểm tra Certbot
    if ! command -v certbot &> /dev/null; then
        error "Certbot không được cài đặt hoặc không khả dụng trong PATH"
        return 1
    else
        CERTBOT_VERSION=$(certbot --version | cut -d' ' -f2)
        log "Certbot: $CERTBOT_VERSION"
    fi
    
    return 0
}

install_dependencies
check_services_availability || error "Có lỗi khi kiểm tra dịch vụ. Vui lòng kiểm tra lại cài đặt!"() {
    case $OS in
        *"CentOS"*|*"Red Hat"*|*"Fedora"*)
            log "Cài đặt các gói cho CentOS/RHEL/Fedora..."
            dnf update -y
            dnf install -y git nginx nodejs npm certbot python3-certbot-nginx postgresql postgresql-server postgresql-contrib postfix mailx uuid pwgen cron
            
            # Khởi tạo PostgreSQL
            postgresql-setup --initdb
            
            # Cài đặt PM2 toàn cục
            npm install -g pm2
            
            # Bật và khởi động dịch vụ
            systemctl enable nginx postgresql postfix crond
            systemctl start nginx postgresql postfix crond
            ;;
            
        *"Ubuntu"*|*"Debian"*)
            log "Cài đặt các gói cho Ubuntu/Debian..."
            apt update
            apt install -y git nginx nodejs npm certbot python3-certbot-nginx postgresql postgresql-contrib postfix mailutils uuid pwgen cron
            
            # Cài đặt PM2 toàn cục
            npm install -g pm2
            
            # Bật và khởi động dịch vụ
            systemctl enable nginx postgresql postfix cron
            systemctl start nginx postgresql postfix cron
            ;;
            
        *)
            error "Hệ điều hành không được hỗ trợ: $OS"
            exit 1
            ;;
    esac
}

install_dependencies

# Mở cổng tường lửa
log "Cấu hình tường lửa..."
if command -v firewall-cmd &> /dev/null; then
    firewall-cmd --permanent --add-service=http
    firewall-cmd --permanent --add-service=https
    firewall-cmd --permanent --add-service=smtp
    firewall-cmd --reload
    log "Đã cấu hình tường lửa với firewall-cmd"
elif command -v ufw &> /dev/null; then
    ufw allow 'Nginx Full'
    ufw allow 'Postfix'
    log "Đã cấu hình tường lửa với ufw"
else
    warn "Không tìm thấy firewall-cmd hoặc ufw. Vui lòng cấu hình tường lửa thủ công."
fi

# Cấu hình PostgreSQL để chấp nhận kết nối từ localhost
log "Cấu hình PostgreSQL..."
PG_HBA_CONF=$(find /etc -name pg_hba.conf)
if [ -f "$PG_HBA_CONF" ]; then
    # Cho phép kết nối từ localhost
    sed -i '/^host.*all.*all.*127.0.0.1\/32.*ident$/s/ident/md5/' "$PG_HBA_CONF"
    
    # Khởi động lại PostgreSQL
    systemctl restart postgresql
fi

# Cấu hình Postfix cho gửi email
log "Cấu hình Postfix cho gửi email..."
POSTFIX_MAIN_CF="/etc/postfix/main.cf"
if [ -f "$POSTFIX_MAIN_CF" ]; then
    # Cấu hình Postfix
    postconf -e "myhostname = $(hostname -f)"
    postconf -e "mydomain = $MAIN_DOMAIN"
    postconf -e "myorigin = \$mydomain"
    postconf -e "inet_interfaces = all"
    postconf -e "mydestination = \$myhostname, localhost.\$mydomain, localhost, \$mydomain"
    
    # Khởi động lại Postfix
    systemctl restart postfix
fi

# Tạo các script chính
log "Tạo các script chính..."

# utils.sh - Các hàm tiện ích
cat > $AUTODEPLOY_ROOT/scripts/utils.sh << 'EOL'
#!/bin/bash

# Các hàm tiện ích dùng chung cho hệ thống auto-deploy

# Thiết lập màu sắc cho output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Thư mục gốc
AUTODEPLOY_ROOT="/opt/autodeploy"

# Tên miền chính
MAIN_DOMAIN="nodejs.io.vn"

# Hàm ghi log
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> $AUTODEPLOY_ROOT/logs/deploy/system.log
}

# Hàm cảnh báo
warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] CẢNH BÁO: $1${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] CẢNH BÁO: $1" >> $AUTODEPLOY_ROOT/logs/deploy/system.log
}

# Hàm báo lỗi
error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] LỖI: $1${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] LỖI: $1" >> $AUTODEPLOY_ROOT/logs/deploy/system.log
    
    # Gửi email thông báo lỗi nếu có email admin trong cấu hình
    if [ -f "$AUTODEPLOY_ROOT/config/global.json" ]; then
        ADMIN_EMAIL=$(grep -o '"adminEmail": "[^"]*"' "$AUTODEPLOY_ROOT/config/global.json" | cut -d'"' -f4)
        if [ -n "$ADMIN_EMAIL" ]; then
            echo "$1" | mail -s "[AUTODEPLOY ERROR] Lỗi hệ thống deploy" "$ADMIN_EMAIL"
        fi
    fi
}

# Hàm tạo mật khẩu ngẫu nhiên
generate_password() {
    local length=${1:-16}
    if command -v pwgen &> /dev/null; then
        pwgen -s $length 1
    else
        tr -dc 'a-zA-Z0-9!@#$%^&*()_+' < /dev/urandom | head -c $length
    fi
}

# Hàm tạo username PostgreSQL an toàn
generate_pg_username() {
    local site_name=$1
    # Chuyển thành chữ thường và loại bỏ ký tự đặc biệt
    local clean_name=$(echo "$site_name" | tr '[:upper:]' '[:lower:]' | tr -d '.-')
    # Thêm tiền tố "user_" để đảm bảo không bắt đầu bằng số
    echo "user_${clean_name}"
}

# Hàm tạo tên database PostgreSQL an toàn
generate_pg_dbname() {
    local site_name=$1
    # Chuyển thành chữ thường và loại bỏ ký tự đặc biệt
    local clean_name=$(echo "$site_name" | tr '[:upper:]' '[:lower:]' | tr -d '.-')
    # Thêm tiền tố "db_" để đảm bảo không bắt đầu bằng số
    echo "db_${clean_name}"
}

# Hàm kiểm tra tên miền có hợp lệ không
is_valid_domain() {
    local domain=$1
    if [[ $domain =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        return 0
    else
        return 1
    fi
}

# Hàm kiểm tra tên site có hợp lệ không
is_valid_site_name() {
    local name=$1
    if [[ $name =~ ^[a-zA-Z0-9][a-zA-Z0-9\-]*$ ]]; then
        return 0
    else
        return 1
    fi
}

# Hàm kiểm tra URL git có hợp lệ không
is_valid_git_url() {
    local url=$1
    # Kiểm tra URL Git cơ bản
    if [[ $url =~ ^(https://|git@)[a-zA-Z0-9.-]+/[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+(.git)?$ ]]; then
        return 0
    else
        return 1
    fi
}

# Hàm kiểm tra cổng có hợp lệ không
is_valid_port() {
    local port=$1
    if [[ $port =~ ^[0-9]+$ ]] && [ $port -ge 1024 ] && [ $port -le 65535 ]; then
        return 0
    else
        return 1
    fi
}

# Hàm kiểm tra xem site đã tồn tại chưa
site_exists() {
    local site_name=$1
    if [ -f "$AUTODEPLOY_ROOT/config/sites/$site_name.json" ]; then
        return 0
    else
        return 1
    fi
}

# Hàm tạo subdomain từ tên site
generate_subdomain() {
    local site_name=$1
    # Đọc domain chính từ cấu hình toàn cục nếu đã tồn tại
    if [ -f "$AUTODEPLOY_ROOT/config/global.json" ]; then
        local configured_domain=$(grep -o '"mainDomain": "[^"]*"' "$AUTODEPLOY_ROOT/config/global.json" | cut -d'"' -f4)
        if [ -n "$configured_domain" ]; then
            echo "${site_name}.${configured_domain}"
            return
        fi
    fi
    # Nếu không có cấu hình, sử dụng biến MAIN_DOMAIN
    echo "${site_name}.${MAIN_DOMAIN}"
}

# Hàm tạo cấu hình Nginx cho một site
generate_nginx_config() {
    local site_name=$1
    local domain=$2
    local port=$3
    local static_path=$4
    local is_spa=${5:-false}
    local with_api=${6:-false}
    
    local config_file="/etc/nginx/conf.d/${domain}.conf"
    
    # Xóa file cấu hình cũ nếu tồn tại
    [ -f "$config_file" ] && rm "$config_file"
    
    # Tạo cấu hình cho static site hoặc SPA
    if [ "$with_api" = "false" ]; then
        cat > "$config_file" << EOF
server {
    listen 80;
    server_name $domain;
    
    root $static_path;
    index index.html index.htm;
    
    access_log $AUTODEPLOY_ROOT/logs/nginx/$site_name/access.log;
    error_log $AUTODEPLOY_ROOT/logs/nginx/$site_name/error.log;
    
    # Cấu hình cho SPA (Single Page Application)
    location / {
        try_files \$uri \$uri/ ${is_spa:+/index.html};
    }
    
    # Cấu hình cho static assets
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg)$ {
        expires 30d;
        add_header Cache-Control "public, no-transform";
    }
    
    # Tiêu đề bảo mật
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options SAMEORIGIN;
    add_header X-XSS-Protection "1; mode=block";
}
EOF
    else
        # Tạo cấu hình cho Node.js API + static site
        cat > "$config_file" << EOF
server {
    listen 80;
    server_name $domain;
    
    root $static_path;
    index index.html index.htm;
    
    access_log $AUTODEPLOY_ROOT/logs/nginx/$site_name/access.log;
    error_log $AUTODEPLOY_ROOT/logs/nginx/$site_name/error.log;
    
    # Cấu hình cho SPA (Single Page Application)
    location / {
        try_files \$uri \$uri/ ${is_spa:+/index.html};
    }
    
    # Cấu hình proxy cho Node.js API
    location /api {
        proxy_pass http://localhost:$port;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    # Cấu hình cho static assets
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg)$ {
        expires 30d;
        add_header Cache-Control "public, no-transform";
    }
    
    # Tiêu đề bảo mật
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options SAMEORIGIN;
    add_header X-XSS-Protection "1; mode=block";
}
EOF
    fi
    
    # Tạo thư mục logs
    mkdir -p "$AUTODEPLOY_ROOT/logs/nginx/$site_name"
    
    # Kiểm tra cấu hình Nginx
    nginx -t
    if [ $? -eq 0 ]; then
        # Nếu cấu hình hợp lệ, reload Nginx
        systemctl reload nginx
        return 0
    else
        error "Cấu hình Nginx không hợp lệ"
        return 1
    fi
}

# Hàm thiết lập SSL với Let's Encrypt
setup_ssl() {
    local domain=$1
    log "Thiết lập SSL với Let's Encrypt cho $domain..."
    
    # Kiểm tra xem certbot đã được cài đặt chưa
    if ! command -v certbot &> /dev/null; then
        error "Certbot chưa được cài đặt. Hãy cài đặt certbot trước khi thiết lập SSL."
        return 1
    fi
    
    # Chạy certbot để cài đặt SSL
    certbot --nginx -d "$domain" --non-interactive --agree-tos --email "admin@$MAIN_DOMAIN" --redirect
    
    if [ $? -ne 0 ]; then
        error "Không thể thiết lập SSL cho $domain"
        return 1
    fi
    
    log "Đã thiết lập SSL thành công cho $domain"
    return 0
}

# Hàm tạo database và user PostgreSQL
create_postgres_db() {
    local site_name=$1
    local db_name=$(generate_pg_dbname "$site_name")
    local db_user=$(generate_pg_username "$site_name")
    local db_password=$(generate_password 16)
    
    log "Tạo database PostgreSQL cho $site_name..."
    
    # Tạo user
    sudo -u postgres psql -c "CREATE USER $db_user WITH PASSWORD '$db_password';" > /dev/null 2>&1
    
    if [ $? -ne 0 ]; then
        error "Không thể tạo user PostgreSQL cho $site_name"
        return 1
    fi
    
    # Tạo database
    sudo -u postgres psql -c "CREATE DATABASE $db_name OWNER $db_user;" > /dev/null 2>&1
    
    if [ $? -ne 0 ]; then
        error "Không thể tạo database PostgreSQL cho $site_name"
        sudo -u postgres psql -c "DROP USER $db_user;" > /dev/null 2>&1
        return 1
    fi
    
    # Ghi thông tin database vào file
    cat > "$AUTODEPLOY_ROOT/config/sites/${site_name}_db.env" << EOF
DB_HOST=localhost
DB_PORT=5432
DB_NAME=$db_name
DB_USER=$db_user
DB_PASSWORD=$db_password
DATABASE_URL=postgresql://$db_user:$db_password@localhost:5432/$db_name
EOF
    
    chmod 600 "$AUTODEPLOY_ROOT/config/sites/${site_name}_db.env"
    
    log "Đã tạo database PostgreSQL thành công cho $site_name"
    return 0
}

# Hàm tạo tài khoản email noreply
create_email_account() {
    local site_name=$1
    local domain=$2
    local email="noreply@$domain"
    local password=$(generate_password 16)
    
    log "Tạo tài khoản email $email..."
    
    # Ghi thông tin email vào file
    cat > "$AUTODEPLOY_ROOT/config/sites/${site_name}_email.env" << EOF
SMTP_HOST=localhost
SMTP_PORT=25
SMTP_USER=$email
SMTP_PASSWORD=$password
SMTP_FROM=$email
EOF
    
    chmod 600 "$AUTODEPLOY_ROOT/config/sites/${site_name}_email.env"
    
    log "Đã tạo thông tin email thành công cho $site_name"
    return 0
}

# Hàm tạo hook post-receive cho Git
generate_post_receive_hook() {
    local site_name=$1
    local hook_file="$AUTODEPLOY_ROOT/repos/$site_name.git/hooks/post-receive"
    
    mkdir -p "$(dirname "$hook_file")"
    
    cat > "$hook_file" << EOF
#!/bin/bash

# Hook tự động triển khai cho $site_name
exec $AUTODEPLOY_ROOT/scripts/deploy.sh "$site_name"
EOF
    
    chmod +x "$hook_file"
}

# Hàm tạo cấu hình site
generate_site_config() {
    local site_name=$1
    local domain=$2
    local git_url=$3
    local port=$4
    local type=$5
    local branch=${6:-main}
    local build_cmd=${7:-"npm run build"}
    local start_cmd=${8:-"npm start"}
    
    local config_file="$AUTODEPLOY_ROOT/config/sites/$site_name.json"
    
    cat > "$config_file" << EOF
{
    "siteName": "$site_name",
    "domain": "$domain",
    "gitUrl": "$git_url",
    "port": $port,
    "type": "$type",
    "branch": "$branch",
    "buildCommand": "$build_cmd",
    "startCommand": "$start_cmd",
    "created": "$(date '+%Y-%m-%d %H:%M:%S')",
    "lastDeploy": null,
    "lastCheck": null,
    "lastCommit": null
}
EOF
}

# Hàm tạo thư mục deployment
create_deployment_dirs() {
    local site_name=$1
    
    mkdir -p "$AUTODEPLOY_ROOT/www/$site_name"
    mkdir -p "$AUTODEPLOY_ROOT/logs/deploy"
    mkdir -p "$AUTODEPLOY_ROOT/logs/nginx/$site_name"
    
    # Tạo git repo
    if [ ! -d "$AUTODEPLOY_ROOT/repos/$site_name.git" ]; then
        mkdir -p "$AUTODEPLOY_ROOT/repos/$site_name.git"
        git init --bare "$AUTODEPLOY_ROOT/repos/$site_name.git"
    fi
}

# Hàm để lấy port tiếp theo có sẵn
get_next_available_port() {
    local start_port=3000
    local ports_in_use=()
    
    # Lấy danh sách các port đã dùng từ config
    for config_file in $AUTODEPLOY_ROOT/config/sites/*.json; do
        if [ -f "$config_file" ]; then
            port=$(grep -o '"port": [0-9]*' "$config_file" | awk '{print $2}')
            ports_in_use+=($port)
        fi
    done
    
    # Tìm port trống tiếp theo
    local port=$start_port
    while true; do
        if [[ ! " ${ports_in_use[@]} " =~ " ${port} " ]]; then
            echo $port
            return
        fi
        ((port++))
    done
}

# Hàm kiểm tra phiên bản Git mới nhất
check_git_update() {
    local site_name=$1
    local git_url=$2
    local branch=$3
    local repo_dir="$AUTODEPLOY_ROOT/repos/$site_name.git"
    local config_file="$AUTODEPLOY_ROOT/config/sites/$site_name.json"
    
    # Cập nhật thời gian kiểm tra cuối cùng
    sed -i "s/\"lastCheck\": .*,/\"lastCheck\": \"$(date '+%Y-%m-%d %H:%M:%S')\",/" "$config_file"
    
    # Kiểm tra xem repo đã được clone chưa
    if [ ! -d "$repo_dir" ]; then
        error "Không tìm thấy repository cho $site_name"
        return 1
    fi
    
    # Tạo thư mục tạm để kiểm tra
    local temp_dir=$(mktemp -d)
    
    # Clone repository
    git clone "$git_url" "$temp_dir" &> /dev/null
    
    if [ $? -ne 0 ]; then
        error "Không thể clone repository từ $git_url"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Chuyển đến thư mục và checkout nhánh
    cd "$temp_dir" || return 1
    git checkout "$branch" &> /dev/null
    
    # Lấy commit hash mới nhất
    local latest_commit=$(git rev-parse HEAD)
    
    # Lấy commit hash cuối cùng đã deploy
    local last_commit=$(grep -o '"lastCommit": "[^"]*"' "$config_file" | cut -d'"' -f4)
    
    # Nếu chưa có commit hash trong cấu hình hoặc commit hash đã thay đổi
    if [ "$last_commit" = "null" ] || [ "$latest_commit" != "$last_commit" ]; then
        # Cập nhật commit hash mới nhất
        sed -i "s/\"lastCommit\": .*,/\"lastCommit\": \"$latest_commit\",/" "$config_file"
        
        # Dọn dẹp
        rm -rf "$temp_dir"
        
        # Có cập nhật mới
        return 0
    else
        # Dọn dẹp
        rm -rf "$temp_dir"
        
        # Không có cập nhật mới
        return 1
    fi
}

# Hàm clone repo từ Git URL
clone_repository() {
    local site_name=$1
    local git_url=$2
    local branch=$3
    local repo_dir="$AUTODEPLOY_ROOT/repos/$site_name.git"
    
    log "Clone repository từ $git_url cho $site_name..."
    
    # Xóa repo cũ nếu có
    if [ -d "$repo_dir" ]; then
        rm -rf "$repo_dir"
    fi
    
    # Tạo thư mục cho repo
    mkdir -p "$repo_dir"
    
    # Clone bare repository
    git clone --mirror "$git_url" "$repo_dir"
    
    if [ $? -ne 0 ]; then
        error "Không thể clone repository từ $git_url"
        return 1
    fi
    
    # Tạo hook post-receive
    generate_post_receive_hook "$site_name"
    
    return 0
}
EOL

# Tạo script add-site.sh
cat > $AUTODEPLOY_ROOT/scripts/add-site.sh << 'EOL'
#!/bin/bash

# Script thêm một trang web mới vào hệ thống auto-deploy

# Đảm bảo script chạy với quyền root
if [[ $EUID -ne 0 ]]; then
   echo "Script này phải được chạy với quyền root" 
   exit 1
fi

# Nạp các hàm tiện ích
source "/opt/autodeploy/scripts/utils.sh"

# Hiển thị cách sử dụng
show_usage() {
    echo "Sử dụng: $0 <site_name> <git_url> [options]"
    echo ""
    echo "Arguments:"
    echo "  <site_name>              Tên site (sẽ tạo subdomain site_name.nodejs.io.vn)"
    echo "  <git_url>                URL của repository Git để clone"
    echo ""
    echo "Options:"
    echo "  --type <type>            Loại dự án (static, spa, node, fullstack) (mặc định: fullstack)"
    echo "  --port <port>            Cổng cho ứng dụng Node.js (tự động nếu không được chỉ định)"
    echo "  --branch <branch>        Nhánh Git để triển khai (mặc định: main)"
    echo "  --build-cmd <command>    Lệnh build (mặc định: npm run build)"
    echo "  --start-cmd <command>    Lệnh khởi động Node.js (mặc định: npm start)"
    echo "  --custom-domain <domain> Tên miền tùy chỉnh (nếu không sử dụng subdomain mặc định)"
    echo ""
    echo "Ví dụ:"
    echo "  $0 myapp https://github.com/user/repo.git --type fullstack --branch main"
    echo "  $0 myapp https://github.com/user/repo.git --custom-domain example.com"
    exit 1
}

# Kiểm tra tham số
if [ $# -lt 2 ]; then
    show_usage
fi

SITE_NAME=$1
GIT_URL=$2
shift 2

# Kiểm tra tên site có hợp lệ không
if ! is_valid_site_name "$SITE_NAME"; then
    error "Tên site không hợp lệ: $SITE_NAME"
    show_usage
fi

# Kiểm tra Git URL có hợp lệ không
if ! is_valid_git_url "$GIT_URL"; then
    error "URL Git không hợp lệ: $GIT_URL"
    show_usage
fi

# Kiểm tra xem site đã tồn tại chưa
if site_exists "$SITE_NAME"; then
    error "Site $SITE_NAME đã tồn tại trong hệ thống"
    exit 1
fi

# Thiết lập giá trị mặc định
TYPE="fullstack"
PORT=$(get_next_available_port)
BRANCH="main"
BUILD_CMD="npm run build"
START_CMD="npm start"
CUSTOM_DOMAIN=""

# Xử lý các tham số tùy chọn
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --type)
            TYPE="$2"
            if [[ ! "$TYPE" =~ ^(static|spa|node|fullstack)$ ]]; then
                error "Loại dự án không hợp lệ. Phải là: static, spa, node, hoặc fullstack"
                exit 1
            fi
            shift 2
            ;;
        --port)
            PORT="$2"
            if ! is_valid_port "$PORT"; then
                error "Cổng không hợp lệ. Phải là số từ 1024 đến 65535"
                exit 1
            fi
            shift 2
            ;;
        --branch)
            BRANCH="$2"
            shift 2
            ;;
        --build-cmd)
            BUILD_CMD="$2"
            shift 2
            ;;
        --start-cmd)
            START_CMD="$2"
            shift 2
            ;;
        --custom-domain)
            CUSTOM_DOMAIN="$2"
            if ! is_valid_domain "$CUSTOM_DOMAIN"; then
                error "Tên miền không hợp lệ: $CUSTOM_DOMAIN"
                exit 1
            fi
            shift 2
            ;;
        *)
            error "Tham số không được hỗ trợ: $1"
            show_usage
            ;;
    esac
done

# Xác định domain sẽ sử dụng
if [ -z "$CUSTOM_DOMAIN" ]; then
    DOMAIN=$(generate_subdomain "$SITE_NAME")
else
    DOMAIN="$CUSTOM_DOMAIN"
fi

# Tạo cấu trúc thư mục cần thiết
log "Tạo cấu trúc thư mục cho $SITE_NAME..."
create_deployment_dirs "$SITE_NAME"

# Clone repository
log "Clone repository từ $GIT_URL..."
clone_repository "$SITE_NAME" "$GIT_URL" "$BRANCH"

# Tạo database PostgreSQL
log "Tạo database PostgreSQL..."
create_postgres_db "$SITE_NAME"

# Tạo tài khoản email
log "Tạo tài khoản email..."
create_email_account "$SITE_NAME" "$DOMAIN"

# Tạo cấu hình site
log "Tạo cấu hình cho $SITE_NAME..."
generate_site_config "$SITE_NAME" "$DOMAIN" "$GIT_URL" "$PORT" "$TYPE" "$BRANCH" "$BUILD_CMD" "$START_CMD"

# Tạo cấu hình Nginx
log "Tạo cấu hình Nginx cho $DOMAIN..."
STATIC_PATH="$AUTODEPLOY_ROOT/www/$SITE_NAME"

if [[ "$TYPE" == "static" ]]; then
    generate_nginx_config "$SITE_NAME" "$DOMAIN" "$PORT" "$STATIC_PATH" "false" "false"
elif [[ "$TYPE" == "spa" ]]; then
    generate_nginx_config "$SITE_NAME" "$DOMAIN" "$PORT" "$STATIC_PATH" "true" "false"
elif [[ "$TYPE" == "node" ]]; then
    generate_nginx_config "$SITE_NAME" "$DOMAIN" "$PORT" "$STATIC_PATH" "false" "true"
elif [[ "$TYPE" == "fullstack" ]]; then
    generate_nginx_config "$SITE_NAME" "$DOMAIN" "$PORT" "$STATIC_PATH" "true" "true"
fi

# Thiết lập SSL
log "Thiết lập SSL cho $DOMAIN..."
setup_ssl "$DOMAIN"

# Cài đặt webhook hoặc tạo cron job cho kiểm tra tự động
log "Thiết lập kiểm tra tự động cập nhật Git..."
CHECKER_SCRIPT="$AUTODEPLOY_ROOT/scripts/check-updates.sh"
CRON_JOB="* * * * * root $CHECKER_SCRIPT $SITE_NAME > /dev/null 2>&1"

# Thêm cronjob cho site mới
grep -q "$SITE_NAME" /etc/crontab || echo "$CRON_JOB" >> /etc/crontab

# Triển khai lần đầu
log "Triển khai lần đầu cho $SITE_NAME..."
$AUTODEPLOY_ROOT/scripts/deploy.sh "$SITE_NAME"

# Hoàn tất
log "Đã thêm site $SITE_NAME thành công!"
echo ""
echo "Thông tin trang web:"
echo "- Tên site: $SITE_NAME"
echo "- Tên miền: $DOMAIN"
echo "- Repository: $GIT_URL (nhánh $BRANCH)"
echo "- Loại: $TYPE"
echo "- Cổng: $PORT"
echo ""
echo "Thông tin database PostgreSQL:"
echo "- Lưu trong file: $AUTODEPLOY_ROOT/config/sites/${SITE_NAME}_db.env"
cat "$AUTODEPLOY_ROOT/config/sites/${SITE_NAME}_db.env"
echo ""
echo "Thông tin email SMTP:"
echo "- Lưu trong file: $AUTODEPLOY_ROOT/config/sites/${SITE_NAME}_email.env"
cat "$AUTODEPLOY_ROOT/config/sites/${SITE_NAME}_email.env"
echo ""
echo "Hướng dẫn cập nhật ứng dụng:"
echo "1. Push code lên repository gốc. Hệ thống sẽ tự động kiểm tra mỗi 5 giây và triển khai khi có cập nhật mới."
echo "2. Hoặc thêm webhook từ GitHub/GitLab tới: (đang phát triển)"
echo ""
echo "Để xem log triển khai: tail -f $AUTODEPLOY_ROOT/logs/deploy/$SITE_NAME.log"
EOL

# Tạo script deploy.sh
cat > $AUTODEPLOY_ROOT/scripts/deploy.sh << 'EOL'
#!/bin/bash

# Script triển khai cho một trang web
# Sử dụng: ./deploy.sh <site_name>

# Kiểm tra tham số
if [ $# -lt 1 ]; then
    echo "Sử dụng: $0 <site_name>"
    exit 1
fi

# Nạp các hàm tiện ích
source "/opt/autodeploy/scripts/utils.sh"

SITE_NAME=$1
CONFIG_FILE="$AUTODEPLOY_ROOT/config/sites/$SITE_NAME.json"
LOG_FILE="$AUTODEPLOY_ROOT/logs/deploy/$SITE_NAME.log"
WWW_DIR="$AUTODEPLOY_ROOT/www/$SITE_NAME"
REPO_DIR="$AUTODEPLOY_ROOT/repos/$SITE_NAME.git"
TEMP_DIR=$(mktemp -d)

# Đảm bảo log file tồn tại
touch "$LOG_FILE"

# Hàm ghi log đặc biệt cho quá trình triển khai
deploy_log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Xử lý khi có lỗi
handle_error() {
    deploy_log "LỖI: $1"
    
    # Gửi email thông báo lỗi
    if [ -f "$AUTODEPLOY_ROOT/config/global.json" ]; then
        ADMIN_EMAIL=$(grep -o '"adminEmail": "[^"]*"' "$AUTODEPLOY_ROOT/config/global.json" | cut -d'"' -f4)
        if [ -n "$ADMIN_EMAIL" ]; then
            echo "Lỗi triển khai $SITE_NAME: $1" | mail -s "[AUTODEPLOY ERROR] Lỗi triển khai $SITE_NAME" "$ADMIN_EMAIL"
        fi
    fi
    
    rm -rf "$TEMP_DIR"
    exit 1
}

# Kiểm tra xem cấu hình có tồn tại không
if [ ! -f "$CONFIG_FILE" ]; then
    handle_error "Không tìm thấy cấu hình cho site $SITE_NAME"
fi

# Đọc cấu hình
DOMAIN=$(grep -o '"domain": "[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)
GIT_URL=$(grep -o '"gitUrl": "[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)
TYPE=$(grep -o '"type": "[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)
PORT=$(grep -o '"port": [0-9]*' "$CONFIG_FILE" | awk '{print $2}')
BRANCH=$(grep -o '"branch": "[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)
BUILD_CMD=$(grep -o '"buildCommand": "[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)
START_CMD=$(grep -o '"startCommand": "[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)

deploy_log "Bắt đầu triển khai $SITE_NAME (Domain: $DOMAIN, Loại: $TYPE, Nhánh: $BRANCH)"

# Clone repository vào thư mục tạm
deploy_log "Clone repository vào thư mục tạm..."
git clone "$REPO_DIR" "$TEMP_DIR" 2>> "$LOG_FILE" || handle_error "Không thể clone repository"

# Chuyển đến thư mục tạm và checkout nhánh yêu cầu
cd "$TEMP_DIR" || handle_error "Không thể chuyển đến thư mục tạm"
git checkout "$BRANCH" 2>> "$LOG_FILE" || handle_error "Không thể checkout nhánh $BRANCH"

# Lấy commit hash hiện tại
CURRENT_COMMIT=$(git rev-parse HEAD)
deploy_log "Commit hiện tại: $CURRENT_COMMIT"

# Cập nhật commit hash trong cấu hình
sed -i "s/\"lastCommit\": .*,/\"lastCommit\": \"$CURRENT_COMMIT\",/" "$CONFIG_FILE"

# Sao chép các file cấu hình database và email vào thư mục tạm
if [ -f "$AUTODEPLOY_ROOT/config/sites/${SITE_NAME}_db.env" ]; then
    deploy_log "Sao chép cấu hình database..."
    cp "$AUTODEPLOY_ROOT/config/sites/${SITE_NAME}_db.env" "$TEMP_DIR/.env.db"
fi

if [ -f "$AUTODEPLOY_ROOT/config/sites/${SITE_NAME}_email.env" ]; then
    deploy_log "Sao chép cấu hình email..."
    cp "$AUTODEPLOY_ROOT/config/sites/${SITE_NAME}_email.env" "$TEMP_DIR/.env.email"
fi

# Tạo hoặc cập nhật file .env
deploy_log "Tạo file .env..."
cat > "$TEMP_DIR/.env" << EOF
# Tự động tạo bởi hệ thống auto-deploy
NODE_ENV=production
PORT=$PORT
EOF

# Thêm cấu hình database và email vào .env
if [ -f "$TEMP_DIR/.env.db" ]; then
    cat "$TEMP_DIR/.env.db" >> "$TEMP_DIR/.env"
fi

if [ -f "$TEMP_DIR/.env.email" ]; then
    cat "$TEMP_DIR/.env.email" >> "$TEMP_DIR/.env"
fi

# Cài đặt dependencies nếu có package.json
if [ -f "$TEMP_DIR/package.json" ]; then
    deploy_log "Cài đặt dependencies..."
    cd "$TEMP_DIR" && npm install --production 2>> "$LOG_FILE" || handle_error "Không thể cài đặt dependencies"
    
    # Chạy lệnh build nếu cần
    if [[ "$TYPE" != "node" && -n "$BUILD_CMD" ]]; then
        deploy_log "Chạy lệnh build: $BUILD_CMD"
        cd "$TEMP_DIR" && eval "$BUILD_CMD" 2>> "$LOG_FILE" || handle_error "Không thể build dự án"
    fi
fi

# Xác định thư mục chứa mã nguồn cuối cùng
if [[ "$TYPE" == "static" || "$TYPE" == "spa" ]]; then
    # Kiểm tra xem build output có thể nằm trong thư mục build hay dist
    if [ -d "$TEMP_DIR/build" ]; then
        FINAL_DIR="$TEMP_DIR/build"
    elif [ -d "$TEMP_DIR/dist" ]; then
        FINAL_DIR="$TEMP_DIR/dist"
    else
        FINAL_DIR="$TEMP_DIR"
    fi
else
    FINAL_DIR="$TEMP_DIR"
fi

# Đảm bảo thư mục www tồn tại
mkdir -p "$WWW_DIR"

# Triển khai mã nguồn
deploy_log "Triển khai mã nguồn đến $WWW_DIR..."
if [[ "$TYPE" == "node" || "$TYPE" == "fullstack" ]]; then
    # Đối với ứng dụng Node.js, sao chép toàn bộ mã nguồn
    rsync -a --delete --exclude='.git' "$TEMP_DIR/" "$WWW_DIR/" 2>> "$LOG_FILE" || handle_error "Không thể sao chép mã nguồn"
else
    # Đối với static/spa, chỉ sao chép nội dung build
    rsync -a --delete "$FINAL_DIR/" "$WWW_DIR/" 2>> "$LOG_FILE" || handle_error "Không thể sao chép mã nguồn"
fi

# Thiết lập quyền
deploy_log "Thiết lập quyền..."
chown -R www-data:www-data "$WWW_DIR" 2>> "$LOG_FILE" || deploy_log "Cảnh báo: Không thể thiết lập quyền cho thư mục $WWW_DIR"

# Xử lý ứng dụng Node.js với PM2
if [[ "$TYPE" == "node" || "$TYPE" == "fullstack" ]]; then
    deploy_log "Quản lý ứng dụng Node.js với PM2..."
    
    # Kiểm tra xem ứng dụng đã được khởi tạo trong PM2 chưa
    if pm2 list | grep -q "$SITE_NAME"; then
        # Nếu đã tồn tại, restart ứng dụng
        deploy_log "Khởi động lại ứng dụng trong PM2..."
        cd "$WWW_DIR" && pm2 restart "$SITE_NAME" 2>> "$LOG_FILE" || handle_error "Không thể khởi động lại ứng dụng"
    else
        # Nếu chưa tồn tại, thêm ứng dụng mới vào PM2
        deploy_log "Thêm ứng dụng vào PM2..."
        
        # Xác định entry point
        if [ -f "$WWW_DIR/ecosystem.config.js" ]; then
            # Sử dụng ecosystem.config.js nếu có
            cd "$WWW_DIR" && pm2 start ecosystem.config.js 2>> "$LOG_FILE" || handle_error "Không thể khởi động ứng dụng với ecosystem.config.js"
        elif [ -f "$WWW_DIR/package.json" ]; then
            # Tìm entry point từ package.json
            if grep -q '"main"' "$WWW_DIR/package.json"; then
                ENTRY_POINT=$(grep -o '"main": "[^"]*"' "$WWW_DIR/package.json" | cut -d'"' -f4)
                cd "$WWW_DIR" && pm2 start "$ENTRY_POINT" --name "$SITE_NAME" --env production 2>> "$LOG_FILE" || handle_error "Không thể khởi động ứng dụng với entry point từ package.json"
            else
                # Sử dụng start command đã cấu hình
                cd "$WWW_DIR" && pm2 start --name "$SITE_NAME" --env production npm -- start 2>> "$LOG_FILE" || handle_error "Không thể khởi động ứng dụng với start command"
            fi
        else
            handle_error "Không thể xác định cách khởi động ứng dụng Node.js"
        fi
    fi
    
    # Lưu cấu hình PM2
    deploy_log "Lưu cấu hình PM2..."
    pm2 save 2>> "$LOG_FILE" || deploy_log "Cảnh báo: Không thể lưu cấu hình PM2"
}

# Cập nhật thời gian triển khai cuối cùng trong cấu hình
sed -i "s/\"lastDeploy\": .*,/\"lastDeploy\": \"$(date '+%Y-%m-%d %H:%M:%S')\",/" "$CONFIG_FILE"

# Dọn dẹp
deploy_log "Dọn dẹp..."
rm -rf "$TEMP_DIR"

deploy_log "Triển khai $SITE_NAME thành công!"
EOL

# Tạo script check-updates.sh
cat > $AUTODEPLOY_ROOT/scripts/check-updates.sh << 'EOL'
#!/bin/bash

# Script kiểm tra cập nhật Git tự động
# Sử dụng: ./check-updates.sh <site_name>

# Kiểm tra tham số
if [ $# -lt 1 ]; then
    echo "Sử dụng: $0 <site_name>"
    exit 1
fi

# Nạp các hàm tiện ích
source "/opt/autodeploy/scripts/utils.sh"

SITE_NAME=$1
CONFIG_FILE="$AUTODEPLOY_ROOT/config/sites/$SITE_NAME.json"

# Kiểm tra xem cấu hình có tồn tại không
if [ ! -f "$CONFIG_FILE" ]; then
    error "Không tìm thấy cấu hình cho site $SITE_NAME"
    exit 1
fi

# Đọc cấu hình
GIT_URL=$(grep -o '"gitUrl": "[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)
BRANCH=$(grep -o '"branch": "[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)

# Kiểm tra cập nhật
if check_git_update "$SITE_NAME" "$GIT_URL" "$BRANCH"; then
    log "Phát hiện cập nhật mới cho $SITE_NAME. Đang triển khai..."
    
    # Thực hiện triển khai
    $AUTODEPLOY_ROOT/scripts/deploy.sh "$SITE_NAME"
fi

exit 0
EOL

# Tạo script remove-site.sh
cat > $AUTODEPLOY_ROOT/scripts/remove-site.sh << 'EOL'
#!/bin/bash

# Script xóa một trang web khỏi hệ thống auto-deploy
# Sử dụng: ./remove-site.sh <site_name> [--force]

# Đảm bảo script chạy với quyền root
if [[ $EUID -ne 0 ]]; then
   echo "Script này phải được chạy với quyền root" 
   exit 1
fi

# Nạp các hàm tiện ích
source "/opt/autodeploy/scripts/utils.sh"

# Kiểm tra tham số
if [ $# -lt 1 ]; then
    echo "Sử dụng: $0 <site_name> [--force]"
    exit 1
fi

SITE_NAME=$1
FORCE=0

if [ "$2" == "--force" ]; then
    FORCE=1
fi

# Kiểm tra xem site có tồn tại không
if ! site_exists "$SITE_NAME"; then
    error "Site $SITE_NAME không tồn tại trong hệ thống"
    exit 1
fi

# Đọc cấu hình site
CONFIG_FILE="$AUTODEPLOY_ROOT/config/sites/$SITE_NAME.json"
DOMAIN=$(grep -o '"domain": "[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)
TYPE=$(grep -o '"type": "[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)

# Xác nhận xóa nếu không có tham số --force
if [ $FORCE -eq 0 ]; then
    read -p "Bạn có chắc chắn muốn xóa site $SITE_NAME ($DOMAIN)? Điều này sẽ xóa tất cả dữ liệu liên quan. (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        log "Hủy thao tác xóa"
        exit 0
    fi
fi

# Dừng ứng dụng Node.js nếu có
if [[ "$TYPE" == "node" || "$TYPE" == "fullstack" ]]; then
    if pm2 list | grep -q "$SITE_NAME"; then
        log "Dừng ứng dụng Node.js..."
        pm2 delete "$SITE_NAME" && pm2 save
    fi
fi

# Đọc thông tin database
if [ -f "$AUTODEPLOY_ROOT/config/sites/${SITE_NAME}_db.env" ]; then
    DB_USER=$(grep "DB_USER=" "$AUTODEPLOY_ROOT/config/sites/${SITE_NAME}_db.env" | cut -d'=' -f2)
    DB_NAME=$(grep "DB_NAME=" "$AUTODEPLOY_ROOT/config/sites/${SITE_NAME}_db.env" | cut -d'=' -f2)
    
    # Xóa database và user
    log "Xóa database PostgreSQL..."
    sudo -u postgres psql -c "DROP DATABASE IF EXISTS $DB_NAME;" > /dev/null 2>&1
    sudo -u postgres psql -c "DROP USER IF EXISTS $DB_USER;" > /dev/null 2>&1
fi

# Xóa cấu hình Nginx và SSL
log "Xóa cấu hình Nginx và SSL..."
if [ -f "/etc/nginx/conf.d/$DOMAIN.conf" ]; then
    rm "/etc/nginx/conf.d/$DOMAIN.conf"
    
    # Xóa cấu hình SSL
    if [ -d "/etc/letsencrypt/live/$DOMAIN" ]; then
        certbot delete --cert-name "$DOMAIN" --non-interactive
    fi
    
    systemctl reload nginx
fi

# Xóa cron job
log "Xóa cron job..."
sed -i "/$SITE_NAME/d" /etc/crontab

# Xóa các thư mục và file liên quan
log "Xóa mã nguồn và cấu hình..."
rm -rf "$AUTODEPLOY_ROOT/www/$SITE_NAME"
rm -rf "$AUTODEPLOY_ROOT/repos/$SITE_NAME.git"
rm -f "$AUTODEPLOY_ROOT/config/sites/$SITE_NAME.json"
rm -f "$AUTODEPLOY_ROOT/config/sites/${SITE_NAME}_db.env"
rm -f "$AUTODEPLOY_ROOT/config/sites/${SITE_NAME}_email.env"
rm -f "$AUTODEPLOY_ROOT/logs/deploy/$SITE_NAME.log"
rm -rf "$AUTODEPLOY_ROOT/logs/nginx/$SITE_NAME"

log "Đã xóa site $SITE_NAME thành công!"
EOL

# Tạo script list-sites.sh
cat > $AUTODEPLOY_ROOT/scripts/list-sites.sh << 'EOL'
#!/bin/bash

# Script liệt kê các trang web trong hệ thống auto-deploy
# Sử dụng: ./list-sites.sh [--format json]

# Nạp các hàm tiện ích
source "/opt/autodeploy/scripts/utils.sh"

# Kiểm tra định dạng output
FORMAT="table"
if [ "$1" == "--format" ] && [ "$2" == "json" ]; then
    FORMAT="json"
fi

# Đếm số lượng sites
SITES_COUNT=$(ls -1 $AUTODEPLOY_ROOT/config/sites/*.json 2>/dev/null | grep -v "_db.env\|_email.env" | wc -l)

if [ $SITES_COUNT -eq 0 ]; then
    if [ "$FORMAT" == "json" ]; then
        echo "[]"
    else
        echo "Không có trang web nào trong hệ thống."
    fi
    exit 0
fi

# Hiển thị thông tin theo định dạng JSON
if [ "$FORMAT" == "json" ]; then
    echo "["
    COUNTER=0
    for config_file in $AUTODEPLOY_ROOT/config/sites/*.json; do
        # Bỏ qua các file cấu hình database và email
        if [[ "$config_file" != *"_db.env"* && "$config_file" != *"_email.env"* ]]; then
            COUNTER=$((COUNTER+1))
            cat "$config_file"
            if [ $COUNTER -lt $SITES_COUNT ]; then
                echo ","
            fi
        fi
    done
    echo "]"
else
    # Hiển thị thông tin dạng bảng
    printf "%-20s %-30s %-15s %-10s %-15s %-25s\n" "SITE NAME" "DOMAIN" "TYPE" "PORT" "BRANCH" "LAST DEPLOY"
    printf "%-20s %-30s %-15s %-10s %-15s %-25s\n" "--------------------" "------------------------------" "---------------" "----------" "---------------" "-------------------------"
    
    for config_file in $AUTODEPLOY_ROOT/config/sites/*.json; do
        # Bỏ qua các file cấu hình database và email
        if [[ "$config_file" != *"_db.env"* && "$config_file" != *"_email.env"* ]]; then
            SITE_NAME=$(grep -o '"siteName": "[^"]*"' "$config_file" | cut -d'"' -f4)
            DOMAIN=$(grep -o '"domain": "[^"]*"' "$config_file" | cut -d'"' -f4)
            TYPE=$(grep -o '"type": "[^"]*"' "$config_file" | cut -d'"' -f4)
            PORT=$(grep -o '"port": [0-9]*' "$config_file" | awk '{print $2}')
            BRANCH=$(grep -o '"branch": "[^"]*"' "$config_file" | cut -d'"' -f4)
            LAST_DEPLOY=$(grep -o '"lastDeploy": "[^"]*"' "$config_file" | cut -d'"' -f4)
            
            if [ "$LAST_DEPLOY" == "null" ]; then
                LAST_DEPLOY="Chưa triển khai"
            fi
            
            printf "%-20s %-30s %-15s %-10s %-15s %-25s\n" "$SITE_NAME" "$DOMAIN" "$TYPE" "$PORT" "$BRANCH" "$LAST_DEPLOY"
        fi
    done
fi
EOL

# Tạo script debug.sh
cat > $AUTODEPLOY_ROOT/scripts/debug.sh << 'EOL'
#!/bin/bash

# Script hiển thị thông tin debug
# Sử dụng: ./debug.sh <site_name>

# Nạp các hàm tiện ích
source "/opt/autodeploy/scripts/utils.sh"

# Kiểm tra tham số
if [ $# -lt 1 ]; then
    echo "Sử dụng: $0 <site_name>"
    exit 1
fi

SITE_NAME=$1
CONFIG_FILE="$AUTODEPLOY_ROOT/config/sites/$SITE_NAME.json"

# Kiểm tra xem site có tồn tại không
if ! site_exists "$SITE_NAME"; then
    error "Site $SITE_NAME không tồn tại trong hệ thống"
    exit 1
fi

# Đọc cấu hình site
DOMAIN=$(grep -o '"domain": "[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)
GIT_URL=$(grep -o '"gitUrl": "[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)
TYPE=$(grep -o '"type": "[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)
PORT=$(grep -o '"port": [0-9]*' "$CONFIG_FILE" | awk '{print $2}')
BRANCH=$(grep -o '"branch": "[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)
LAST_DEPLOY=$(grep -o '"lastDeploy": "[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)
LAST_CHECK=$(grep -o '"lastCheck": "[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)
LAST_COMMIT=$(grep -o '"lastCommit": "[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)

echo "=== THÔNG TIN DEBUG CHO $SITE_NAME ==="
echo ""
echo "Thông tin cơ bản:"
echo "- Tên site: $SITE_NAME"
echo "- Tên miền: $DOMAIN"
echo "- Repository: $GIT_URL (nhánh $BRANCH)"
echo "- Loại: $TYPE"
echo "- Cổng: $PORT"
echo "- Triển khai cuối: $LAST_DEPLOY"
echo "- Kiểm tra cuối: $LAST_CHECK"
echo "- Commit cuối: $LAST_COMMIT"
echo ""

echo "Kiểm tra dịch vụ:"
echo "- Nginx:"
if systemctl is-active --quiet nginx; then
    echo "  + Trạng thái: Đang chạy"
else
    echo "  + Trạng thái: KHÔNG CHẠY"
fi

echo "  + Cấu hình site:"
if [ -f "/etc/nginx/conf.d/$DOMAIN.conf" ]; then
    echo "    * Đã tìm thấy cấu hình"
    nginx -t
else
    echo "    * KHÔNG TÌM THẤY cấu hình"
fi

echo "- SSL:"
if [ -d "/etc/letsencrypt/live/$DOMAIN" ]; then
    echo "  + Đã cài đặt SSL"
    certbot certificates -d "$DOMAIN"
else
    echo "  + CHƯA cài đặt SSL"
fi

echo "- PostgreSQL:"
if [ -f "$AUTODEPLOY_ROOT/config/sites/${SITE_NAME}_db.env" ]; then
    DB_NAME=$(grep "DB_NAME=" "$AUTODEPLOY_ROOT/config/sites/${SITE_NAME}_db.env" | cut -d'=' -f2)
    echo "  + Database: $DB_NAME"
    # Kiểm tra xem database có tồn tại không
    if sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw "$DB_NAME"; then
        echo "  + Trạng thái: Database tồn tại"
    else
        echo "  + Trạng thái: DATABASE KHÔNG TỒN TẠI"
    fi
else
    echo "  + KHÔNG TÌM THẤY cấu hình database"
fi

echo "- Node.js PM2:"
if [[ "$TYPE" == "node" || "$TYPE" == "fullstack" ]]; then
    if pm2 list | grep -q "$SITE_NAME"; then
        echo "  + Trạng thái: Đang chạy"
        pm2 show "$SITE_NAME"
    else
        echo "  + Trạng thái: KHÔNG CHẠY"
    fi
else
    echo "  + Không áp dụng cho loại site này"
fi

echo ""
echo "Các đường dẫn quan trọng:"
echo "- Thư mục mã nguồn: $AUTODEPLOY_ROOT/www/$SITE_NAME"
echo "- Repository Git: $AUTODEPLOY_ROOT/repos/$SITE_NAME.git"
echo "- File cấu hình: $CONFIG_FILE"
echo "- File log triển khai: $AUTODEPLOY_ROOT/logs/deploy/$SITE_NAME.log"
echo "- File log Nginx: $AUTODEPLOY_ROOT/logs/nginx/$SITE_NAME/access.log và error.log"

echo ""
echo "10 dòng log triển khai gần đây nhất:"
tail -n 10 "$AUTODEPLOY_ROOT/logs/deploy/$SITE_NAME.log" 2>/dev/null || echo "Không tìm thấy file log"

echo ""
echo "Kiểm tra kết nối:"
if ping -c 1 "$DOMAIN" &> /dev/null; then
    echo "- Có thể ping tới $DOMAIN"
else
    echo "- KHÔNG THỂ ping tới $DOMAIN"
fi

if curl -s --head "http://$DOMAIN" &> /dev/null; then
    echo "- HTTP (80) có thể kết nối"
else
    echo "- HTTP (80) KHÔNG THỂ kết nối"
fi

if curl -s --head "https://$DOMAIN" &> /dev/null; then
    echo "- HTTPS (443) có thể kết nối"
else
    echo "- HTTPS (443) KHÔNG THỂ kết nối"
fi

if [[ "$TYPE" == "node" || "$TYPE" == "fullstack" ]]; then
    if curl -s "http://localhost:$PORT" &> /dev/null; then
        echo "- Cổng $PORT có thể kết nối (Node.js)"
    else
        echo "- Cổng $PORT KHÔNG THỂ kết nối (Node.js)"
    fi
fi

echo ""
echo "Các lệnh hữu ích:"
echo "- Triển khai lại: $AUTODEPLOY_ROOT/scripts/deploy.sh $SITE_NAME"
echo "- Xem log triển khai: tail -f $AUTODEPLOY_ROOT/logs/deploy/$SITE_NAME.log"
echo "- Xem log Nginx: tail -f $AUTODEPLOY_ROOT/logs/nginx/$SITE_NAME/error.log"
if [[ "$TYPE" == "node" || "$TYPE" == "fullstack" ]]; then
    echo "- Xem log PM2: pm2 logs $SITE_NAME"
    echo "- Restart ứng dụng: pm2 restart $SITE_NAME"
fi
EOL

# Thiết lập quyền thực thi cho các script
chmod +x $AUTODEPLOY_ROOT/scripts/*.sh

# Tạo cấu hình toàn cục
cat > $AUTODEPLOY_ROOT/config/global.json << EOL
{
    "version": "1.0.0",
    "setupDate": "$(date '+%Y-%m-%d %H:%M:%S')",
    "serverName": "$(hostname)",
    "mainDomain": "$MAIN_DOMAIN",
    "useHttps": true,
    "defaultBranch": "main",
    "adminEmail": "admin@$MAIN_DOMAIN",
    "checkInterval": 5
}
EOL

# Tạo cron job mẫu cho check-updates.sh
cat > /etc/cron.d/autodeploy << 'EOL'
# Cron job cho hệ thống auto-deploy
# Kiểm tra cập nhật mỗi phút cho tất cả các site

*/1 * * * * root find /opt/autodeploy/config/sites -name "*.json" -not -path "*_db.env*" -not -path "*_email.env*" -exec basename {} \; | sed 's/\.json$//' | xargs -I{} /opt/autodeploy/scripts/check-updates.sh {} >/dev/null 2>&1
EOL

chmod 644 /etc/cron.d/autodeploy

# Tạo tệp init.d để khởi động lại PM2 khi khởi động
log "Cấu hình PM2 để tự khởi động khi server khởi động..."
env PATH=$PATH:/usr/bin pm2 startup -u root --hp /root
pm2 save

# Hiển thị hướng dẫn sử dụng
log "Thiết lập server hoàn tất!"
echo ""
echo "Hệ thống auto-deploy cho $MAIN_DOMAIN đã được cài đặt thành công!"
echo ""
echo "CẤU HÌNH DNS QUAN TRỌNG:"
echo "Đảm bảo bạn đã cấu hình DNS wildcard cho $MAIN_DOMAIN:"
echo "- Bản ghi A: $MAIN_DOMAIN -> $SERVER_IP"
echo "- Bản ghi A: *.$MAIN_DOMAIN -> $SERVER_IP"
echo ""
echo "Để quản lý các trang web:"
echo "1. Thêm trang web mới:"
echo "   $AUTODEPLOY_ROOT/scripts/add-site.sh myapp https://github.com/username/repo.git --type fullstack"
echo ""
echo "2. Xóa trang web:"
echo "   $AUTODEPLOY_ROOT/scripts/remove-site.sh myapp"
echo ""
echo "3. Liệt kê các trang web:"
echo "   $AUTODEPLOY_ROOT/scripts/list-sites.sh"
echo ""
echo "4. Debug trang web:"
echo "   $AUTODEPLOY_ROOT/scripts/debug.sh myapp"
echo ""
echo "Hệ thống sẽ tự động kiểm tra cập nhật từ GitHub mỗi 5 giây và triển khai khi có cập nhật mới."
echo "Tất cả các trang web sẽ tự động được cấu hình với SSL Let's Encrypt."
echo ""
echo "Mỗi trang web sẽ có:"
echo "- Subdomain tự động tạo: <site_name>.$MAIN_DOMAIN"
echo "- Database PostgreSQL"
echo "- Tài khoản email SMTP"
echo "- File .env với các thông tin cấu hình"
echo ""
echo "Thư mục các script: $AUTODEPLOY_ROOT/scripts/"
echo "Thư mục cấu hình: $AUTODEPLOY_ROOT/config/"
echo "Thư mục mã nguồn: $AUTODEPLOY_ROOT/www/"
echo "Thư mục repository Git: $AUTODEPLOY_ROOT/repos/"
echo "Thư mục log: $AUTODEPLOY_ROOT/logs/"
