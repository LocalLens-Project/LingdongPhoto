# 灵动来信加密协议与独立验证

协议版本：v1。参考版本：4.0.0（Build 202649）。本目录包含加密协议说明和独立参考实现；信件业务模块与服务端实现不属于本目录范围。

## 正常投递

1. 寄件端使用系统安全随机数为每封信生成 32 字节内容密钥（AES-256），另生成独立撤回凭证。
2. 正文文档先在本机序列化，再以 AES-GCM 加密；nonce 为 12 字节，认证标签为 16 字节。
3. `body.iv` 是 nonce 的无填充 Base64URL，`body.ciphertext` 是“密文字节 + 认证标签”的无填充 Base64URL。
4. 正文 AAD 为 `lingdong-letter-v1:<id>:<palette>:<style>:1`。它绑定标识、配色、样式和模板版本；开启/到期时间不直接写入此 AAD，正式阅读器还会在解密后核对内外文档的一致性。
5. 普通上传包不包含明文正文、原始内容密钥或解锁密码。寄件设备使用 Keychain 保存内容密钥和撤回凭证。
6. 收件端下载密文后，在本机或浏览器中完成解密。

协议采用共享秘密进行客户端内容加密，不包含收件人公钥身份验证或前向保密机制。

## 两种密钥传递方式

| 模式 | 链接 | 内容密钥的取得方式 |
| --- | --- | --- |
| 完整链接 | `https://example.invalid/letter/<id>#k=<Base64URL>` | 从 URL fragment 取出内容密钥 |
| 分开密码 | `https://example.invalid/letter/<id>#mode=password` | 用另行发送的密码在收件端解开 `wrappedKey` |

密码模式使用 16 字节随机盐、PBKDF2-HMAC-SHA256、600,000 次迭代，派生 32 字节包装密钥；以 AES-256-GCM 包装随机内容密钥。包装 AAD 为 `lingdong-letter-v1:<id>:key`。密码未直接用作正文密钥，也不随普通上传发送；派生参数与加密后的包装密钥可以存放在服务器。密码强度仍影响离线猜测成本，迭代次数不能代替高熵密码。

fragment 不会随浏览器的普通 HTTP 页面请求自动发送，但接收网页脚本能读取它；持有完整链接的人可以取得解密能力，转发链接、二维码或通过其他平台传递时需要考虑该平台及接收人的访问。分开密码应通过另一渠道传递。

## 密文包与可见元信息

公开的传输字段包括 `version`、`templateVersion`、`id`、`palette`、`style`、`opensAt`、`expiresAt`、`body`、可选的 `wrappedKey` / `salt` / `iterations`，以及 `revokeHash`。`revokeHash` 是独立随机撤回凭证的 SHA-256 摘要，不是内容密钥。

服务器可看到外层标识、模板、配色、开启/到期时间、密文长度、密码模式和必要的账号、额度、连接等业务元信息。开启、撤回与到期通过服务器控制密文领取；已被收件人保存的明文、密钥和密文不受该领取控制影响。

## 主动举报披露

正常投递不提供原始内容密钥。收件人在已解锁后选择“提交举报并提供信件内容”，会主动提交本封内容密钥，审核方由此可以解密整封信。该动作是明确的内容披露例外；“仅举报骚扰，不提供信件内容”不提交密钥，但举报说明本身会提供给服务方。

## 独立示例与验证范围

`EncryptionCore.swift` 是独立参考实现，保持上述 AES-GCM、Base64URL、PBKDF2、AAD 和链接片段规则，并增加示例输入检查。它不包含生产信件文档模型、完整上传/领取客户端或正式阅读器，示例明文也不是生产文档 schema。

在安装 Xcode command-line tools 与 Node.js 的 macOS 上运行：

```sh
bash Transparency/run-checks.sh
```

测试完全离线，只使用虚构文本。覆盖 Swift CryptoKit → Web Crypto 解密、反向解密、密码派生与密钥包装、错误密钥、篡改 AAD、篡改认证标签，以及参考链接/上传对象的密钥边界。固定密钥、密码、salt 和 nonce 仅用于可复现的合成测试向量；正常参考调用使用安全随机 nonce。

验证对象为本目录中的参考实现和合成测试向量，覆盖算法互操作与参考对象字段；验证范围不包含正式 App 二进制、实际网络请求、完整业务或线上部署。浏览器阅读器由服务器提供，其脚本能够访问链接片段、密钥和解密后的内容。

## 本地存储是另一层保护

生产客户端另有本机信匣加密与设备身份验证。它们和传输密钥机制不同，不包含在本独立示例中；本示例也不提供 Apple 登录、购买、审核、风控或数据库实现。

## 参考规范

- [AES-GCM / NIST SP 800-38D](https://csrc.nist.gov/pubs/sp/800/38/d/final)
- [PBKDF2 / RFC 8018](https://www.rfc-editor.org/rfc/rfc8018)
- [URI fragment / RFC 3986 §3.5](https://www.rfc-editor.org/rfc/rfc3986#section-3.5)
- [Web Cryptography API](https://www.w3.org/TR/WebCryptoAPI/)

---

## English scope

This material describes client-side AES-256-GCM encryption with a random 32-byte content key, a 12-byte nonce and a 16-byte authentication tag. Password mode wraps the content key using PBKDF2-HMAC-SHA256 (600,000 iterations, 16-byte random salt). Direct links carry the key in a URL fragment; password links carry only a mode marker. Normal uploads contain ciphertext and visible metadata, not the raw content key or password.

Voluntary content-disclosing reports submit the content key for that letter. Browser code can read the fragment and plaintext. The reference checks demonstrate algorithm interoperability, not full production-client behavior, deployed-server correctness, recipient authentication, forward secrecy, or reproducibility of the official binary. Server, letter business logic and full reader sources are intentionally outside this publication candidate.
