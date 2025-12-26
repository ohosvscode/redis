#!/usr/bin/env node

/**
 * 从 build-profile.json5 提取签名配置信息
 * 使用方法: node extract_build_profile.js <build-profile.json5路径> <字段名>
 * 
 * 支持的字段名:
 * - profile: Provision Profile 文件路径
 * - certpath: 证书文件路径
 * - storeFile: Keystore 文件路径
 * - storePassword: Keystore 密码
 * - keyAlias: 密钥别名
 * - keyPassword: 密钥密码
 * - signAlg: 签名算法
 */

const fs = require('fs');
const JSON5 = require('json5');

if (process.argv.length < 4) {
    console.error('用法: node extract_build_profile.js <build-profile.json5路径> <字段名>');
    process.exit(1);
}

const buildProfilePath = process.argv[2];
const fieldName = process.argv[3];

try {
    if (!fs.existsSync(buildProfilePath)) {
        process.exit(1);
    }

    const content = fs.readFileSync(buildProfilePath, 'utf8');
    const config = JSON5.parse(content);

    // 提取第一个 signingConfig 的 material 字段
    const signingConfigs = config?.app?.signingConfigs;
    if (!signingConfigs || signingConfigs.length === 0) {
        process.exit(1);
    }

    const material = signingConfigs[0]?.material;
    if (!material) {
        process.exit(1);
    }

    // 根据字段名提取值
    let value = '';
    switch (fieldName) {
        case 'profile':
            value = material.profile || '';
            break;
        case 'certpath':
            value = material.certpath || '';
            break;
        case 'storeFile':
            value = material.storeFile || '';
            break;
        case 'storePassword':
            value = material.storePassword || '';
            break;
        case 'keyAlias':
            value = material.keyAlias || '';
            break;
        case 'keyPassword':
            value = material.keyPassword || '';
            break;
        case 'signAlg':
            value = material.signAlg || '';
            break;
        default:
            process.exit(1);
    }

    if (value) {
        console.log(value);
    } else {
        process.exit(1);
    }
} catch (error) {
    process.exit(1);
}

