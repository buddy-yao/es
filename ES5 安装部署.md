<!--author: meesong-->
<!--data: 2016-11-11-->

> 本文以 ArchLinux 为例

# ElasticSearch-5 安装及配置

1. 下载及解压
   参考：[Install Elasticsearch with .zip or .tar.gz](https://www.elastic.co/guide/en/elasticsearch/reference/current/zip-targz.html)  
   存放目录自己定，比如我的就是 `~/Software/elasticsearch/node`

2. ElasticSearch 配置
   * config/elasticsearch.yml  
     参考配置  
     ```yaml
     # ---------------------------------- Cluster -----------------------------------
     # 集群名
     cluster.name: ms-es
     #
     # ------------------------------------ Node ------------------------------------
     # 节点名
     node.name: master_ingest_0
     # 节点类型设置，不同组合不同功能
     # 各类型组合及其功能详见 [Node](https://www.elastic.co/guide/en/elasticsearch/reference/5.0/modules-node.html#modules-node)
     node.master: true
     node.data: false
     node.ingest: true
     #
     # Add custom attributes to the node:
     #
     #node.attr.rack: r1
     #
     # ----------------------------------- Paths ------------------------------------
     # data 目录，用逗号分隔多个位置，设置另外目录是为了方便迁移和升级
     path.data: /home/meesong/elasticsearch/data
     # logs 目录
     #path.logs: /home/meesong/elasticsearch/logs
     #
     # ----------------------------------- Memory -----------------------------------
     # 锁内存，作用详见 [Elasticsearch重要文章之二：堆内存的大小和swapping](http://zhaoyanblog.com/archives/744.html)
     bootstrap.memory_lock: true
     #
     # ---------------------------------- Network -----------------------------------
     #
     # Set the bind address to a specific IP (IPv4 or IPv6):
     # 因为是在虚拟机里面搭建的，所以要在虚拟机外部访问绑定一个ip地址
     network.host: 192.168.253.129
     #
     # Set a custom port for HTTP:
     #
     #http.port: 9200
     #
     # For more information, see the documentation at:
     # <http://www.elastic.co/guide/en/elasticsearch/reference/current/modules-network.html>
     #
     # ----------------------------------- HTTP -------------------------------------
     # 这部分配置是给 elasticsearch-head 插件使用的
     # 各个参数的含义详见 [HTTP](https://www.elastic.co/guide/en/elasticsearch/reference/5.0/modules-http.html)
     http.cors.enabled: true
     http.cors.allow-origin: *
     # --------------------------------- Discovery ----------------------------------
     #
     # Pass an initial list of hosts to perform discovery when new node is started:
     # The default list of hosts is ["127.0.0.1", "[::1]"]
     # 因为绑定了ip，所以这里要写上所有master的地址，不然各个节点不能发现集群
     discovery.zen.ping.unicast.hosts: ["192.168.253.129:9300"]
     #
     # Prevent the "split brain" by configuring the majority of nodes (total number of nodes / 2 + 1):
     # 由于我只有一个master节点，所以我设置了 1
     discovery.zen.minimum_master_nodes: 1
     #
     # For more information, see the documentation at:
     # <http://www.elastic.co/guide/en/elasticsearch/reference/current/modules-discovery.html>
     #
     # ---------------------------------- Various -----------------------------------
     #
     # Disable starting multiple nodes on a single system:
     # 另外，在同一个服务器部署多个节点的话，这里要写上最多在同一服务器允许部署多少节点
     node.max_local_storage_nodes: 1
     #
     # Require explicit names when deleting indices:
     #
     #action.destructive_requires_name: true
     #
     # ------------------------------------------------------------------------------
     # 另外需要注意的是，ES5版本中，不能直接在配置文件设置 主分片和副本分片的默认数量。
     ```
   
   * config/jvm.options  
     ES5版本中，jvm参数由这个配置文件设定  
     jvm设置里面，我就改了一处，就是虚拟内存大小  
     具体设置多少，参见 [Elasticsearch重要文章之二：堆内存的大小和swapping](http://zhaoyanblog.com/archives/744.html)

     下面是参考配置
     ```yaml
     # Xms represents the initial size of total heap space
     # Xmx represents the maximum size of total heap space

     -Xms512m
     -Xmx512m
     ```

3. Linux 配置
   Linux 配置部分先参考官方文档 [Important System Configuration](https://www.elastic.co/guide/en/elasticsearch/reference/current/system-config.html)

   首先先看一下各项参数是否已经满足 ES5 的要求，然后进行针对性修改
   ```bash
   ulimit -a

   ➜  ~ ulimit -a
   -t: cpu time (seconds)              unlimited
   -f: file size (blocks)              unlimited
   -d: data seg size (kbytes)          unlimited
   -s: stack size (kbytes)             8192
   -c: core file size (blocks)         unlimited
   -m: resident set size (kbytes)      unlimited
   -u: processes                       7727
   -n: file descriptors                65536
   -l: locked-in-memory size (kbytes)  unlimited
   -v: address space (kbytes)          unlimited
   -x: file locks                      unlimited
   -i: pending signals                 7727
   -q: bytes in POSIX msg queues       819200
   -e: max nice                        0
   -r: max rt priority                 0
   -N 15:                              unlimited
   ```
   
   * file descriptors (nofile), locked-in-memory size (memlock), Number of threads (nproc)

   ```bash
   # 1. 首先更改系统 /etc/security/limits.conf 文件
   # 其中 domain 字段中，* 表示除了 root 用户的所有用户，所以 root 用户的配置要另外写一份。
   # 当然也可以针对用户进行设置
   # 各个参数含义见 `man limits.conf`

   #<domain>      <type>  <item>          <value>
   root            soft    nofile          65536
   root            hard    nofile          65536
   *               soft    nofile          65536
   *               hard    nofile          65536

   root            soft    memlock         infinity
   root            hard    memlock         infinity
   *               soft    memlock         infinity
   *               hard    memlock         infinity
   ```

   ```bash
   # 2. 然后在 /etc/pam.d/login 和 /etc/pam.d/su 添加下面这条
   session      required    pam_limits.so
   ```

   注销重新登录生效

   * sshd.service limits

   不过呢~你通过ssh登录的终端发现 limits 设置并没有生效，为什么呢？  
   因为 ssh 使用了默认的 limits 配置，然后通过 ssh 登录的终端，创建的 shell 都是由 ssh 来 fork 出来的，
   所以通过 ssh 终端启动的进程都继承了 ssh 的 limits 配置...  
   所以我们通过修改 sshd.service 服务的limits配置来达到目的

   ```bash
   # 对于远程ssh是不受 limits.conf 限制的
   # 如果要让ssh应用修改需要修改sshd.server的limit设置 (仅 systemd 的系统服务管理器)
   #
   # 首先 sudo systemctl cat sshd.service 得到路径和相关配置信息
   sudo systemctl cat sshd.service

   # 输入如下信息
   # /usr/lib/systemd/system/sshd.service
   [Unit]
   Description=OpenSSH Daemon
   Wants=sshdgenkeys.service
   After=sshdgenkeys.service
   After=network.target

   [Service]
   ExecStart=/usr/bin/sshd -D
   ExecReload=/bin/kill -HUP $MAINPID
   KillMode=process
   Restart=always

   [Install]
   WantedBy=multi-user.target
   # This service file runs an SSH daemon that forks for each incoming connection.
   # If you prefer to spawn on-demand daemons, use sshd.socket and sshd@.service.

   # --------------------------------------------------

   # 然后，我们在这里只需要路径信息，根据路径写这个服务的额外配置信息
   # 首先创建这个服务的配置目录
   mkdir /usr/lib/systemd/system/sshd.service.d/
   # 然后创建配置文件
   sudo vim /usr/lib/systemd/system/sshd.service.d/override.conf
   # 在里面输入下面这些内容，这样通过ssh远程来创建的进程才会应用limit的设置
   # 具体的配置信息可以参考 man systemd.exec
   [Service]
   LimitNOFILE=65536
   LimitMEMLOCK=infinity
   ```

   重启服务生效
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl restart sshd.service
   ```

   * Virtual memory

   最后一项就是设置 vm.max_map_count  
   ```bash
   sudo vim /etc/sysctl.conf
   # 在后面添加
   vm.max_map_count=262144
   # 然后
   sudo sysctl -p
   ```

# ElasticSearch5-Head 安装

  插件地址：[ElasticSearch5-Head](https://github.com/mobz/elasticsearch-head#running-with-built-in-server)

  ElasticSearch5-Head 插件与 2.4.X 版本不同，已经不再是一个插件，而是作为一个独立的服务而存在。  
  所以，安装也相对繁琐很多。

  下面是安装流程
  ```bash
  git clone git://github.com/mobz/elasticsearch-head.git
  cd elasticsearch-head
  sudo pacman -S npm
  npm install
  npm install -g grunt-cli
  grunt server # 这条即启动 elasticsearch-head 服务
  ```

  因为我是在虚拟机里面安装的elasticsearch-head，所以我想在虚拟机外部访问就需要像elasticsearch那样绑定一个ip地址  
  ```bash
  # 修改 /elasticsearch-head/Gruntfile.js
  # 将 connect 域参考如下修改
  # Gruntfile.js 配置文件connect参数参考见 [grunt-contrib-connect](https://github.com/gruntjs/grunt-contrib-connect#open) 

    connect: {
        server: {
            options: {
                hostname: '192.168.253.129', # 这个就是绑定ip地址
                port: 9100,
                base: '.',
                keepalive: true
            }
        }
    }
  ```

# Maven 安装

安装 Maven 主要就是为了编译下面两个插件的...  
Arch 大法还是很简单的..可以直接通过包管理器安装

```bash
sudo pacman -S maven
```

# elasticsearch-analysis-ik 安装

```bash
git clone https://github.com/medcl/elasticsearch-analysis-ik.git
mvn package
unzip -d ~/Software/elasticsearch/node-1/plugins/elasticsearch-analysis-ik target/releases/elasticsearch-analysis-ik-5.0.0.zip
```


# elasticsearch-analysis-pinyin 安装

```
git clone https://github.com/medcl/elasticsearch-analysis-pinyin.git
mvn package
unzip -d ~/Software/elasticsearch/node-1/plugins/elasticsearch-analysis-pinyin target/releases/elasticsearch-analysis-pinyin-5.0.0.zip
```

