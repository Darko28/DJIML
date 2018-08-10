//
//  TextureLoader.swift
//  DJIML
//
//  Created by Darko on 2018/8/8.
//  Copyright © 2018 Darko. All rights reserved.
//

import MetalKit


let textureLoader: MTKTextureLoader = {
    return MTKTextureLoader(device: MTLCreateSystemDefaultDevice()!)
}()


/**
  Loads a texture from the main bundle.
 */
public func loadTexture(named fileName: String) -> MTLTexture? {
    if let url = Bundle.main.url(forResource: fileName, withExtension: "") {
        return loadTexture(url: url)
    } else {
        print("Error: could not find image \(fileName)")
        return nil
    }
}


/**
  Loads a texture from the specified URL.
 */
public func loadTexture(url: URL) -> MTLTexture? {
    do {
        return try textureLoader.newTexture(URL: url, options: [MTKTextureLoader.Option.SRGB : NSNumber(value: false)])
    } catch {
        print("Error: could not load texture \(error)")
        return nil
    }
}
