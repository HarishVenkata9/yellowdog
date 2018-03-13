exec { 'apt_update':
        command     => "/usr/bin/apt update",
        logoutput   => 'on_failure'
}

exec { "add-apt-repository-oracle":
        command => "/usr/bin/add-apt-repository -y ppa:webupd8team/java",
        logoutput   => 'on_failure',
        notify => Exec["apt_update"]
}

exec { "set-licence-selected":
        command => '/bin/echo debconf shared/accepted-oracle-license-v1-1 select true | /usr/bin/debconf-set-selections',
        logoutput  => 'on_failure'
}

exec { "set-licence-seen":
        command => '/bin/echo debconf shared/accepted-oracle-license-v1-1 seen true | /usr/bin/debconf-set-selections',
        logoutput  => 'on_failure'
}

package { "oracle-java8-installer":
        ensure => "installed",
        require  => [Exec['add-apt-repository-oracle'], Exec['set-licence-selected'], Exec['set-licence-seen']]
}

package { "tomcat8":
        ensure => "installed",
        require  => Package['oracle-java8-installer']
}

exec{'sample_war':
        command => "/usr/bin/wget -q https://tomcat.apache.org/tomcat-8.0-doc/appdev/sample/sample.war -O /var/lib/tomcat8/webapps/sample.war",
        notify => Service['tomcat8']
}

service { 'tomcat8':
        ensure  => 'running',
        enable  => true,
        require => Package['tomcat8']
}

define wait_for_port ( $protocol = 'tcp', $retry = 10 ) {
  $port = $title
  exec { "wait-for-port${port}":
    command  => "until fuser ${port}/${protocol}; do i=\$[i+1]; [ \$i -gt ${retry} ] && break || sleep 1; done",
    provider => 'shell',
  }
}

wait_for_port { '8080': 
	retry => "30" 
}

define url($url, $content = undef, $wait = 0) {
    exec { 'wget':
        name => "/usr/bin/curl -s -I '${url}' | grep -q '${content}'; sleep ${wait}; exit $?",
    }
}

url { 'Tomcat_Webapp':
	url => "http://localhost:8080/sample/",
	content => "200 OK",
	wait => 10
}
