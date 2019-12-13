/*
 * Copyright 2014-2019 the original author or authors.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package org.fisco.bcos;

import org.fisco.bcos.channel.client.P12Manager;
import org.fisco.bcos.web3j.crypto.Credentials;
import org.fisco.bcos.web3j.crypto.ECKeyPair;
import org.fisco.bcos.web3j.crypto.EncryptType;
import org.fisco.bcos.web3j.crypto.gm.GenCredential;
import org.springframework.context.ApplicationContext;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.support.ClassPathXmlApplicationContext;

@Configuration
public class Encrypt{
    //创建普通外部账户
    EncryptType.encryptType = 0;
    //创建国密外部账户，向国密区块链节点发送交易需要使用国密外部账户
// EncryptType.encryptType = 1;
    Credentials credentials = GenCredential.create();
    //账户地址
    String address = credentials.getAddress();
    //账户私钥
    String privateKey = credentials.getEcKeyPair().getPrivateKey().toString(16);
    //账户公钥
    String publicKey = credentials.getEcKeyPair().getPublicKey().toString(16);

    //通过指定外部账户私钥使用指定的外部账户
    Credentials credentials = GenCredential.create(privateKey);

    //加载Bean
    ApplicationContext context = new ClassPathXmlApplicationContext("classpath:applicationContext.xml");
    P12Manager p12 = context.getBean(P12Manager.class);
    //提供密码获取ECKeyPair，密码在生产p12账户文件时指定
    ECKeyPair p12KeyPair = p12.getECKeyPair(p12.getPassword());

    //以十六进制串输出私钥和公钥
    System.out.println("p12 privateKey: " + p12KeyPair.getPrivateKey().toString(16));
    System.out.println("p12 publicKey: " + p12KeyPair.getPublicKey().toString(16));

    //生成web3sdk使用的Credentials
    Credentials credentials = GenCredential.create(p12KeyPair.getPrivateKey().toString(16));
    System.out.println("p12 Address: " + credentials.getAddress());


}
